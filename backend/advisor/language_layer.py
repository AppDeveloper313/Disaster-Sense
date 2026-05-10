"""
Language Agnostic Layer for Tri-lingual Support.

Detects and handles three input languages:
  1. English
  2. Roman Urdu (Hinglish/Urdu written in Latin script)
  3. Pure Urdu (Nastaliq / UTF-8 Arabic script)

All inputs are internally translated to English for processing.
Responses are translated back to the user's original language.
"""

import logging
import re
from enum import Enum
from typing import Optional

logger = logging.getLogger(__name__)


class Language(str, Enum):
    ENGLISH = "english"
    ROMAN_URDU = "roman_urdu"
    PURE_URDU = "pure_urdu"


# ── Roman Urdu common words / patterns ────────────────────────────────────────
# These words are strong indicators of Roman Urdu when text is in Latin script.
ROMAN_URDU_MARKERS = {
    # Pronouns & auxiliaries
    "kya", "hai", "hain", "ho", "tha", "thi", "the", "hoga", "hogi",
    "mein", "main", "mujhe", "mere", "mera", "meri",
    "tum", "tumhara", "tumhari", "aap", "apka", "apki",
    "woh", "yeh", "ye", "unka", "uska", "uski",
    "hum", "humara", "humari", "hamara", "hamari",
    # Common verbs
    "kar", "karo", "karna", "karta", "karti", "karein",
    "bolo", "batao", "bataye", "bataiye", "batana",
    "dekho", "dekha", "dekhna", "dekhein",
    "suno", "suna", "sunna", "sunein",
    "jao", "jana", "jayein", "chalo", "chalein",
    "ata", "aati", "aaye", "aao", "aana",
    "raha", "rahi", "rahe",
    # Weather-related
    "barish", "baarish", "garmi", "sardi", "toofan", "tufan",
    "mausam", "hawa", "dhoop", "bijli", "badal",
    "paani", "pani", "sailab", "selab",
    # Disaster-related
    "zalzala", "zelzela", "bhoonchaal", "khatara", "khatrnak",
    "tabahi", "afat", "aafat", "nuqsan", "madad",
    # Question words
    "kahan", "kab", "kyun", "kaise", "kaisa", "kaisi",
    "kitna", "kitni", "kitne", "kidhar", "konsa",
    # Connectors
    "aur", "lekin", "magar", "kyunke", "agar", "toh", "to",
    "phir", "abhi", "ab", "kal", "aaj", "parson",
    "wahan", "yahan", "idhar", "udhar",
    # Other common
    "achha", "acha", "theek", "thik", "sahi", "galat",
    "bohot", "bohat", "bahut", "zyada", "kam", "bhi",
    "nahi", "nahin", "nah", "haan", "ji",
    "sheher", "shehr", "ilaka", "ghar",
    "log", "logon", "awam",
    "pakistan", "karachi", "lahore", "islamabad",
}

# ── Urdu script Unicode range ────────────────────────────────────────────────
# Arabic script block: U+0600–U+06FF (covers Urdu, Arabic, Persian)
# Extended Arabic: U+0750–U+077F, U+FB50–U+FDFF, U+FE70–U+FEFF
URDU_SCRIPT_PATTERN = re.compile(r"[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]")


def detect_language(text: str) -> Language:
    """
    Detect the language of input text.

    Detection strategy:
    1. If >30% of characters are Urdu/Arabic script → Pure Urdu
    2. If Latin script but contains Roman Urdu markers → Roman Urdu
    3. Default → English

    Args:
        text: User's input text.

    Returns:
        Detected Language enum value.
    """
    if not text or not text.strip():
        return Language.ENGLISH

    cleaned = text.strip()

    # Count Urdu script characters
    urdu_chars = len(URDU_SCRIPT_PATTERN.findall(cleaned))
    total_non_space = len(re.sub(r"\s", "", cleaned))

    if total_non_space > 0 and (urdu_chars / total_non_space) > 0.3:
        logger.info(f"🔤 Language detected: Pure Urdu ({urdu_chars}/{total_non_space} Urdu chars)")
        return Language.PURE_URDU

    # Check for Roman Urdu markers in Latin-script text
    words = set(re.findall(r"[a-zA-Z]+", cleaned.lower()))
    roman_urdu_hits = words & ROMAN_URDU_MARKERS

    if len(roman_urdu_hits) >= 2:
        logger.info(
            f"🔤 Language detected: Roman Urdu "
            f"(markers found: {', '.join(list(roman_urdu_hits)[:5])})"
        )
        return Language.ROMAN_URDU

    # Check for single strong marker with short text
    if len(roman_urdu_hits) >= 1 and len(words) <= 5:
        logger.info(f"🔤 Language detected: Roman Urdu (short text with marker)")
        return Language.ROMAN_URDU

    logger.info("🔤 Language detected: English")
    return Language.ENGLISH


def get_translation_prompt(text: str, source_lang: Language) -> Optional[str]:
    """
    Build a prompt to translate text to English for internal processing.

    Args:
        text: Original user text.
        source_lang: Detected language of the text.

    Returns:
        Translation prompt string, or None if already English.
    """
    if source_lang == Language.ENGLISH:
        return None

    if source_lang == Language.ROMAN_URDU:
        return (
            "Translate the following Roman Urdu (Urdu written in Latin/English script) "
            "text to English. Preserve the original meaning and context accurately. "
            "Only output the English translation, nothing else.\n\n"
            f"Roman Urdu text: {text}"
        )

    if source_lang == Language.PURE_URDU:
        return (
            "Translate the following Urdu text (written in Nastaliq/Arabic script) "
            "to English. Preserve the original meaning and context accurately. "
            "Only output the English translation, nothing else.\n\n"
            f"Urdu text: {text}"
        )

    return None


def get_response_translation_prompt(
    english_response: str,
    target_lang: Language,
) -> Optional[str]:
    """
    Build a prompt to translate an English response back to the user's language.

    Args:
        english_response: The English response from the risk engine/LLM.
        target_lang: The language to translate into.

    Returns:
        Translation prompt string, or None if target is English.
    """
    if target_lang == Language.ENGLISH:
        return None

    if target_lang == Language.ROMAN_URDU:
        return (
            "Translate the following English text to Roman Urdu "
            "(Urdu written in Latin/English script, as spoken in Pakistan). "
            "Use common Roman Urdu spellings. Keep city names, numbers, and technical "
            "terms in English. Make it sound natural and conversational like a Pakistani "
            "would text their friend. Only output the Roman Urdu translation.\n\n"
            f"English text:\n{english_response}"
        )

    if target_lang == Language.PURE_URDU:
        return (
            "Translate the following English text to Urdu (in Nastaliq/Arabic script). "
            "Use proper Urdu grammar and vocabulary. Keep city names, numbers, and "
            "technical measurement units in English numerals where natural. "
            "Make it clear, formal but accessible. Only output the Urdu translation.\n\n"
            f"English text:\n{english_response}"
        )

    return None


# ── Quick inline translations for common short phrases ────────────────────────
# These avoid an LLM call for trivial greetings / acknowledgments.
QUICK_TRANSLATIONS = {
    Language.ROMAN_URDU: {
        "hello": "hello",
        "hi": "hi",
        "salam": "hello",
        "assalam o alaikum": "hello, peace be upon you",
        "kya haal hai": "how are you",
        "shukriya": "thank you",
        "mausam kaisa hai": "how is the weather",
        "barish hogi": "will it rain",
        "baarish hogi": "will it rain",
        "garmi hai": "it is hot",
        "kitni garmi hai": "how hot is it",
    },
    Language.PURE_URDU: {
        "سلام": "hello",
        "السلام علیکم": "hello, peace be upon you",
        "شکریہ": "thank you",
        "موسم کیسا ہے": "how is the weather",
        "بارش ہوگی": "will it rain",
        "گرمی ہے": "it is hot",
        "کتنی گرمی ہے": "how hot is it",
        "مدد": "help",
    },
}


def quick_translate_to_english(text: str, lang: Language) -> Optional[str]:
    """
    Attempt a quick dictionary-based translation for common phrases.

    Returns None if no quick translation is available (needs LLM).
    """
    if lang == Language.ENGLISH:
        return text

    lookup = QUICK_TRANSLATIONS.get(lang, {})
    normalized = text.strip().lower()
    return lookup.get(normalized)
