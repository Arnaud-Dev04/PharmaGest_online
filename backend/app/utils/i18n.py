"""
I18n Utility - Handles loading and retrieving translation strings.
"""

import json
import os
from typing import Dict

# Global cache for loaded messages
_MESSAGES: Dict[str, Dict[str, str]] = {}
DEFAULT_LOCALE = "fr"

def load_messages():
    """Load JSON translation files from app/i18n directory."""
    global _MESSAGES
    base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    i18n_path = os.path.join(base_path, "i18n")
    
    # Load FR
    try:
        with open(os.path.join(i18n_path, "messages_fr.json"), "r", encoding="utf-8") as f:
            _MESSAGES["fr"] = json.load(f)
    except FileNotFoundError:
        print("Warning: messages_fr.json not found")
        _MESSAGES["fr"] = {}

    # Load EN
    try:
        with open(os.path.join(i18n_path, "messages_en.json"), "r", encoding="utf-8") as f:
            _MESSAGES["en"] = json.load(f)
    except FileNotFoundError:
        print("Warning: messages_en.json not found")
        _MESSAGES["en"] = {}


def get_message(key: str, locale: str = DEFAULT_LOCALE) -> str:
    """
    Retrieve a message by key and locale.
    Falls back to default locale if key not found in requested locale.
    """
    if not _MESSAGES:
        load_messages()
        
    locale = locale.lower()
    if locale not in _MESSAGES:
        locale = DEFAULT_LOCALE
        
    # Try getting from requested locale
    msg = _MESSAGES.get(locale, {}).get(key)
    
    # Fallback to default locale if not found
    if not msg and locale != DEFAULT_LOCALE:
        msg = _MESSAGES.get(DEFAULT_LOCALE, {}).get(key)
        
    # Fallback to key itself if absolutely nothing found
    return msg or key
