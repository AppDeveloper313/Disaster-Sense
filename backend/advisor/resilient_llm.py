"""
Resilient LLM API Wrapper with 3-Tier Fallback.

Tier 1: Google Gemini (Primary)
Tier 2: Groq — Llama 3-70b (if Tier 1 fails with 429/500)
Tier 3: OpenRouter — Unified Access (final fail-safe)
"""

import asyncio
import logging
import os
import time
from dataclasses import dataclass, field
from enum import Enum
from typing import List, Optional

from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)


class LLMTier(str, Enum):
    GEMINI = "gemini"
    GROQ = "groq"
    OPENROUTER = "openrouter"


@dataclass
class LLMResponse:
    """Structured response from the resilient LLM."""
    text: str
    tier_used: LLMTier
    model_name: str
    latency_ms: float
    fallback_errors: List[str] = field(default_factory=list)


# ── Retryable HTTP status codes ──────────────────────────────────────────────
RETRYABLE_STATUS_CODES = {429, 500, 502, 503, 504}


class _GeminiProvider:
    """Tier 1 — Google Gemini."""

    def __init__(self):
        import google.generativeai as genai

        api_key = os.getenv("GEMINI_API_KEY", "").strip()
        if not api_key:
            raise ValueError("GEMINI_API_KEY not set")
        genai.configure(api_key=api_key)
        self.model = genai.GenerativeModel("gemini-2.0-flash")
        self.tier = LLMTier.GEMINI
        self.model_name = "gemini-2.0-flash"

    async def generate(self, system_prompt: str, user_message: str) -> str:
        """Generate a response using Gemini."""
        combined_prompt = f"{system_prompt}\n\nUser: {user_message}"
        loop = asyncio.get_event_loop()
        response = await loop.run_in_executor(
            None, lambda: self.model.generate_content(combined_prompt)
        )
        return response.text


class _GroqProvider:
    """Tier 2 — Groq (Llama 3-70b)."""

    def __init__(self):
        from groq import Groq

        api_key = os.getenv("GROQ_API_KEY", "").strip()
        if not api_key:
            raise ValueError("GROQ_API_KEY not set")
        self.client = Groq(api_key=api_key)
        self.tier = LLMTier.GROQ
        self.model_name = "llama-3.3-70b-versatile"

    async def generate(self, system_prompt: str, user_message: str) -> str:
        """Generate a response using Groq."""
        loop = asyncio.get_event_loop()

        def _call():
            response = self.client.chat.completions.create(
                model=self.model_name,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_message},
                ],
                temperature=0.7,
                max_tokens=2048,
            )
            return response.choices[0].message.content

        return await loop.run_in_executor(None, _call)


class _OpenRouterProvider:
    """Tier 3 — OpenRouter (unified access, final fail-safe)."""

    def __init__(self):
        from openai import OpenAI

        api_key = os.getenv("OPENROUTER_API_KEY", "").strip()
        if not api_key:
            api_key = os.getenv("openrouter_api_key", "").strip()
        if not api_key:
            raise ValueError("OPENROUTER_API_KEY not set")

        self.client = OpenAI(
            base_url="https://openrouter.ai/api/v1",
            api_key=api_key,
        )
        self.tier = LLMTier.OPENROUTER
        self.model_name = "meta-llama/llama-3.3-70b-instruct"

    async def generate(self, system_prompt: str, user_message: str) -> str:
        """Generate a response using OpenRouter."""
        loop = asyncio.get_event_loop()

        def _call():
            response = self.client.chat.completions.create(
                model=self.model_name,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_message},
                ],
                temperature=0.7,
                max_tokens=2048,
            )
            content = response.choices[0].message.content
            if content is None:
                raise ValueError("OpenRouter returned empty response")
            return content

        return await loop.run_in_executor(None, _call)


class ResilientLLM:
    """
    3-Tier Resilient LLM with automatic fallback.

    Usage:
        llm = ResilientLLM()
        response = await llm.generate(system_prompt, user_message)
        print(response.text, response.tier_used)
    """

    def __init__(self):
        self._providers = []
        self._init_providers()

    def _init_providers(self):
        """Initialize providers in priority order. Skip unavailable ones."""
        provider_classes = [
            ("Gemini", _GeminiProvider),
            ("Groq", _GroqProvider),
            ("OpenRouter", _OpenRouterProvider),
        ]

        for name, cls in provider_classes:
            try:
                provider = cls()
                self._providers.append(provider)
                logger.info(f"✅ LLM Provider initialized: {name} ({provider.model_name})")
            except Exception as e:
                logger.warning(f"⚠️  LLM Provider skipped: {name} — {e}")

        if not self._providers:
            raise RuntimeError(
                "No LLM providers available! Check your API keys in .env"
            )

    async def generate(
        self,
        system_prompt: str,
        user_message: str,
        *,
        max_retries: int = 2,
    ) -> LLMResponse:
        """
        Generate a response with automatic tier fallback.

        Tries each provider in order. On retryable errors (429, 500, etc.),
        falls through to the next tier. Returns an LLMResponse with metadata
        about which tier actually responded.

        Args:
            system_prompt: System-level instructions for the LLM.
            user_message: The user's message/query.
            max_retries: Max retries per provider before falling through.

        Returns:
            LLMResponse with the generated text and metadata.

        Raises:
            RuntimeError: If all providers fail.
        """
        fallback_errors: List[str] = []

        for provider in self._providers:
            for attempt in range(1, max_retries + 1):
                start_time = time.perf_counter()
                try:
                    text = await provider.generate(system_prompt, user_message)
                    latency_ms = (time.perf_counter() - start_time) * 1000

                    logger.info(
                        f"🟢 LLM response from {provider.tier.value} "
                        f"({provider.model_name}) in {latency_ms:.0f}ms"
                    )

                    return LLMResponse(
                        text=text.strip(),
                        tier_used=provider.tier,
                        model_name=provider.model_name,
                        latency_ms=round(latency_ms, 2),
                        fallback_errors=fallback_errors,
                    )

                except Exception as e:
                    latency_ms = (time.perf_counter() - start_time) * 1000
                    error_msg = (
                        f"{provider.tier.value} attempt {attempt}/{max_retries} "
                        f"failed ({latency_ms:.0f}ms): {type(e).__name__}: {e}"
                    )
                    logger.warning(f"🔴 {error_msg}")
                    fallback_errors.append(error_msg)

                    # Check if the error is retryable
                    is_retryable = _is_retryable_error(e)

                    if is_retryable and attempt < max_retries:
                        wait_time = 1.0 * attempt
                        logger.info(f"⏳ Retrying {provider.tier.value} in {wait_time}s...")
                        await asyncio.sleep(wait_time)
                    else:
                        # Move to next provider
                        break

        # All providers exhausted
        raise RuntimeError(
            f"All LLM providers failed after exhausting all tiers. "
            f"Errors: {'; '.join(fallback_errors)}"
        )


def _is_retryable_error(error: Exception) -> bool:
    """Check if an error is retryable (429/5xx)."""
    error_str = str(error).lower()

    # Check for HTTP status codes in the error message
    for code in RETRYABLE_STATUS_CODES:
        if str(code) in error_str:
            return True

    # Check for rate limit keywords
    rate_limit_keywords = ["rate limit", "too many requests", "quota", "overloaded"]
    return any(kw in error_str for kw in rate_limit_keywords)
