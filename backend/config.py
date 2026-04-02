"""Configuration for DisasterSense data fetcher."""

from dataclasses import dataclass
from typing import Dict, Tuple

# Priority cities in Pakistan with coordinates (latitude, longitude)
PAKISTAN_CITIES: Dict[str, Tuple[float, float]] = {
    "Karachi": (24.8607, 67.0011),
    "Lahore": (31.5497, 74.3436),
    "Peshawar": (34.0151, 71.5249),
    "Quetta": (30.1798, 66.9750),
    "Sukkur": (27.7052, 68.8574),
}

# Open-Meteo API endpoints
OPEN_METEO_FORECAST_URL = "https://api.open-meteo.com/v1/forecast"
OPEN_METEO_ARCHIVE_URL = "https://archive-api.open-meteo.com/v1/archive"

# Flood risk thresholds (in mm)
@dataclass
class FloodThresholds:
    LOW_MAX: float = 30.0      # 0-30mm: low risk
    MEDIUM_MAX: float = 50.0   # 30-50mm: medium risk
    # Above 50mm: high risk

FLOOD_THRESHOLDS = FloodThresholds()

# API request settings
REQUEST_TIMEOUT = 30  # seconds
MAX_RETRIES = 3
RETRY_DELAY = 2  # seconds
