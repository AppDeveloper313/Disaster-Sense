"""
Chat Handler — Orchestrates the multilingual weather risk advisor.

Flow:
  1. Detect language of user input
  2. Translate to English if needed
  3. Resolve city from query
  4. Build risk context from the Contextual Risk Engine
  5. Generate response via Resilient LLM
  6. Translate response back to user's language
"""

import logging
import re
from dataclasses import dataclass, field
from typing import List, Optional

from ..config import PAKISTAN_CITIES
from .language_layer import (
    Language,
    detect_language,
    get_response_translation_prompt,
    get_translation_prompt,
    quick_translate_to_english,
)
from .resilient_llm import ResilientLLM, LLMResponse, LLMTier
from .risk_engine import ContextualRiskEngine, RiskContext, format_risk_context_for_llm

logger = logging.getLogger(__name__)

# ── City name aliases (Roman Urdu / Urdu / common misspellings) ──────────────
CITY_ALIASES = {
    "khi": "Karachi", "karachi": "Karachi", "کراچی": "Karachi",
    "lhr": "Lahore", "lahore": "Lahore", "لاہور": "Lahore",
    "isb": "Islamabad", "islamabad": "Islamabad", "اسلام آباد": "Islamabad",
    "rwp": "Rawalpindi", "rawalpindi": "Rawalpindi", "pindi": "Rawalpindi", "راولپنڈی": "Rawalpindi",
    "pew": "Peshawar", "peshawar": "Peshawar", "پشاور": "Peshawar",
    "quetta": "Quetta", "کوئٹہ": "Quetta",
    "multan": "Multan", "ملتان": "Multan",
    "faisalabad": "Faisalabad", "فیصل آباد": "Faisalabad", "lyallpur": "Faisalabad",
    "hyderabad": "Hyderabad", "حیدرآباد": "Hyderabad",
    "sukkur": "Sukkur", "سکھر": "Sukkur",
    "gujranwala": "Gujranwala", "sialkot": "Sialkot",
    "bahawalpur": "Bahawalpur", "sargodha": "Sargodha",
    "abbottabad": "Abbottabad", "mardan": "Mardan",
    "gilgit": "Gilgit", "skardu": "Skardu",
    "muzaffarabad": "Muzaffarabad", "mirpur": "Mirpur",
    "gwadar": "Gwadar", "turbat": "Turbat",
}


SYSTEM_PROMPT = """You are DisasterSense AI — Pakistan's multilingual weather risk advisor.

ROLE:
- You are an expert disaster risk analyst specializing in Pakistan's geography, climate patterns, and infrastructure vulnerabilities.
- You provide actionable, context-aware weather risk advisories.
- You NEVER just report raw numbers. You ALWAYS explain what those numbers MEAN for the specific location.

LANGUAGE RULE (HIGHEST PRIORITY — NEVER BREAK THIS):
- The user's input language is detected and injected into the context block below.
- You MUST respond in EXACTLY the same language the user wrote in:
  * If they wrote in English → respond fully in English.
  * If they wrote in Roman Urdu (Urdu in Latin script, e.g. "Karachi mein barish hogi?") → respond fully in Roman Urdu.
  * If they wrote in Urdu script (اردو) → respond fully in Urdu script.
- Do NOT mix languages in your response. Do NOT translate or switch unless the user asks you to.
- This rule overrides everything else.

RISK ASSESSMENT RULES:
1. The risk context block below contains a pre-computed risk score and factors from real weather data.
2. You MUST treat those numbers as ground truth — do NOT invent or contradict them.
3. You SHOULD add your own qualitative reasoning on top: explain *why* the numbers matter for this specific city's terrain, drainage, and history.
4. Compare current data against the location's specific thresholds (provided in context).
5. Explain WHY a city is vulnerable (drainage, terrain, river proximity).
6. Reference historical patterns when available ("This is X% above the 6-month average").
7. Give specific, actionable recommendations (not generic safety tips).
8. If risk score is >60, lead with an urgent warning.
9. Be conversational but authoritative. Think of yourself as a senior meteorologist briefing a city official.
10. Use emojis sparingly for visual hierarchy (🔴 🟡 🟢 for risk levels).
11. Always mention the data source timeframe (e.g., "Based on the next 3-day forecast...").
12. If asked about a city you don't have specific thresholds for, use general Pakistan averages but mention this caveat.

RESPONSE FORMAT:
- Keep responses concise but informative (200-400 words).
- Use bullet points for multiple risk factors.
- End with a clear recommendation section.
"""


@dataclass
class ChatResponse:
    """Complete response from the chat handler."""
    response_text: str
    detected_language: str
    city_resolved: Optional[str]
    risk_score: Optional[float]
    tier_used: str
    model_name: str
    latency_ms: float
    fallback_errors: List[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "response": self.response_text,
            "metadata": {
                "detected_language": self.detected_language,
                "city_resolved": self.city_resolved,
                "risk_score": self.risk_score,
                "llm_tier": self.tier_used,
                "llm_model": self.model_name,
                "latency_ms": self.latency_ms,
                "fallback_errors": self.fallback_errors,
            },
        }


class WeatherRiskChatHandler:
    """Main orchestrator for the multilingual weather risk advisor."""

    def __init__(self):
        self.llm = ResilientLLM()
        self.risk_engine = ContextualRiskEngine()

    async def handle_message(
        self,
        user_message: str,
        city_hint: Optional[str] = None,
    ) -> ChatResponse:
        """
        Process a user chat message end-to-end.

        Args:
            user_message: Raw user input (any language).
            city_hint: Optional explicit city name from the client.

        Returns:
            ChatResponse with the advisory and metadata.
        """
        # 1. Detect language
        detected_lang = detect_language(user_message)
        logger.info(f"💬 Input language: {detected_lang.value}")

        # 2. Translate to English if needed
        english_query = await self._translate_to_english(user_message, detected_lang)
        logger.info(f"📝 English query: {english_query[:100]}...")

        # 3. Resolve city
        city = self._resolve_city(english_query, user_message, city_hint)
        logger.info(f"🏙️  Resolved city: {city or 'None (general query)'}")

        # 4. Build risk context
        risk_context: Optional[RiskContext] = None
        context_text = ""
        if city:
            try:
                risk_context = await self.risk_engine.build_risk_context(city)
                context_text = format_risk_context_for_llm(risk_context)
            except Exception as e:
                logger.error(f"Risk engine error: {e}")
                context_text = f"[Risk data unavailable for {city}: {e}]"

        # 5. Build full system prompt
        full_system = SYSTEM_PROMPT
        if context_text:
            full_system += f"\n\n{context_text}"

        # 6. Generate response via LLM
        llm_response = await self.llm.generate(full_system, english_query)

        # 7. Translate back to user's language if needed
        final_text = await self._translate_response(
            llm_response.text, detected_lang
        )

        return ChatResponse(
            response_text=final_text,
            detected_language=detected_lang.value,
            city_resolved=city,
            risk_score=risk_context.risk_score if risk_context else None,
            tier_used=llm_response.tier_used.value,
            model_name=llm_response.model_name,
            latency_ms=llm_response.latency_ms,
            fallback_errors=llm_response.fallback_errors,
        )

    async def _translate_to_english(self, text: str, lang: Language) -> str:
        """Translate user input to English."""
        if lang == Language.ENGLISH:
            return text

        # Try quick translation first
        quick = quick_translate_to_english(text, lang)
        if quick:
            return quick

        # Use LLM for translation
        prompt = get_translation_prompt(text, lang)
        if not prompt:
            return text

        try:
            response = await self.llm.generate(
                "You are a precise translator. Only output the translation.",
                prompt,
            )
            return response.text
        except Exception as e:
            logger.error(f"Translation to English failed: {e}")
            return text  # Fall back to original

    async def _translate_response(self, english_text: str, target_lang: Language) -> str:
        """Translate English response back to user's language."""
        if target_lang == Language.ENGLISH:
            return english_text

        prompt = get_response_translation_prompt(english_text, target_lang)
        if not prompt:
            return english_text

        try:
            response = await self.llm.generate(
                "You are a precise translator. Only output the translation.",
                prompt,
            )
            return response.text
        except Exception as e:
            logger.error(f"Translation to {target_lang.value} failed: {e}")
            return english_text  # Fall back to English

    def _resolve_city(
        self,
        english_query: str,
        original_query: str,
        city_hint: Optional[str],
    ) -> Optional[str]:
        """Resolve city from query text or hint."""
        # Priority 1: Explicit hint from client
        if city_hint:
            resolved = CITY_ALIASES.get(city_hint.lower())
            if resolved:
                return resolved
            # Check PAKISTAN_CITIES directly
            for name in PAKISTAN_CITIES:
                if name.lower() == city_hint.lower():
                    return name

        # Priority 2: Search in original text (catches Urdu script names)
        for alias, city in CITY_ALIASES.items():
            if alias in original_query.lower() or alias in original_query:
                return city

        # Priority 3: Search in English translation
        query_lower = english_query.lower()
        for alias, city in CITY_ALIASES.items():
            if alias in query_lower:
                return city

        # Priority 4: Check all PAKISTAN_CITIES names
        for name in PAKISTAN_CITIES:
            if name.lower() in query_lower:
                return name

        return None
