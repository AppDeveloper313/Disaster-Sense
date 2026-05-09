"""Configuration for DisasterSense data fetcher."""

from dataclasses import dataclass
from typing import Dict, Tuple

# Priority cities in Pakistan with coordinates (latitude, longitude)
PAKISTAN_CITIES: Dict[str, Tuple[float, float]] = {
    # ── Sindh ──────────────────────────────────────────────
    "Karachi":        (24.8607, 67.0011),
    "Hyderabad":      (25.3960, 68.3578),
    "Sukkur":         (27.7052, 68.8574),
    "Larkana":        (27.5570, 68.2141),
    "Nawabshah":      (26.2483, 68.4100),
    "Mirpur Khas":    (25.5276, 69.0159),
    "Khairpur":       (27.5295, 68.7592),
    "Jacobabad":      (28.2769, 68.4514),
    "Dadu":           (26.7319, 67.7752),
    "Badin":          (24.6561, 68.8372),
    "Thatta":         (24.7461, 67.9236),
    "Tando Adam":     (25.7646, 68.6618),
    # ── Punjab ─────────────────────────────────────────────
    "Lahore":         (31.5497, 74.3436),
    "Faisalabad":     (31.4504, 73.1350),
    "Rawalpindi":     (33.5651, 73.0169),
    "Multan":         (30.1575, 71.6836),
    "Gujranwala":     (32.1877, 74.1945),
    "Sialkot":        (32.4945, 74.5229),
    "Bahawalpur":     (29.3956, 71.6836),
    "Sargodha":       (32.0836, 72.6711),
    "Jhang":          (31.2681, 72.3181),
    "Sheikhupura":    (31.7167, 73.9850),
    "Rahim Yar Khan": (28.4202, 70.2952),
    "Gujrat":         (32.5742, 74.0789),
    "Sahiwal":        (30.6682, 73.1114),
    "Kasur":          (31.1176, 74.4508),
    "Okara":          (30.8138, 73.4534),
    "Jhelum":         (32.9425, 73.7257),
    "Khanewal":       (30.3018, 71.9321),
    "Muzaffargarh":   (30.0734, 71.1936),
    "Dera Ghazi Khan":(30.0489, 70.6455),
    "Mianwali":       (32.5839, 71.5370),
    "Chakwal":        (32.9328, 72.8556),
    "Attock":         (33.7667, 72.3597),
    "Chiniot":        (31.7200, 72.9789),
    "Vehari":         (30.0450, 72.3489),
    "Lodhran":        (29.5339, 71.6333),
    "Sadiqabad":      (28.3091, 70.1327),
    "Bhakkar":        (31.6082, 71.0648),
    "Layyah":         (30.9693, 70.9428),
    "Nankana Sahib":  (31.4500, 73.7083),
    # ── Khyber Pakhtunkhwa ─────────────────────────────────
    "Peshawar":       (34.0151, 71.5249),
    "Mardan":         (34.1986, 72.0404),
    "Mingora":        (34.7717, 72.3600),
    "Abbottabad":     (34.1463, 73.2117),
    "Kohat":          (33.5869, 71.4414),
    "Dera Ismail Khan":(31.8626, 70.9019),
    "Nowshera":       (34.0153, 71.9747),
    "Swabi":          (34.1200, 72.4700),
    "Mansehra":       (34.3300, 73.2000),
    "Haripur":        (33.9942, 72.9331),
    "Bannu":          (32.9888, 70.6044),
    "Chitral":        (35.8518, 71.7864),
    "Hangu":          (33.5311, 71.0572),
    # ── Balochistan ────────────────────────────────────────
    "Quetta":         (30.1798, 66.9750),
    "Turbat":         (26.0028, 63.0472),
    "Gwadar":         (25.1216, 62.3254),
    "Hub":            (25.0500, 66.8875),
    "Zhob":           (31.3515, 69.4493),
    "Khuzdar":        (27.8000, 66.6100),
    "Chaman":         (30.9210, 66.4597),
    "Noshki":         (29.5530, 66.0130),
    "Sibi":           (29.5430, 67.8770),
    # ── Islamabad Capital Territory ────────────────────────
    "Islamabad":      (33.6844, 73.0479),
    # ── Gilgit-Baltistan ───────────────────────────────────
    "Gilgit":         (35.9208, 74.3144),
    "Skardu":         (35.2972, 75.6308),
    # ── Azad Jammu & Kashmir ───────────────────────────────
    "Muzaffarabad":   (34.3700, 73.4711),
    "Mirpur":         (33.1484, 73.7514),
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
