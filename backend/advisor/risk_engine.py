"""
Contextual Risk Engine with Location Sensitivity Matrix.

Compares current weather + 6-month historical data against per-city
thresholds to generate meaningful risk context for the LLM advisor.
"""

import asyncio
import logging
from dataclasses import dataclass, field
from datetime import date, timedelta
from typing import Dict, List, Optional, Tuple

import httpx

try:
    from ..config import PAKISTAN_CITIES, OPEN_METEO_FORECAST_URL, OPEN_METEO_ARCHIVE_URL
except ImportError:
    from config import PAKISTAN_CITIES, OPEN_METEO_FORECAST_URL, OPEN_METEO_ARCHIVE_URL

logger = logging.getLogger(__name__)


# ── Location Sensitivity Matrix ──────────────────────────────────────────────
@dataclass
class LocationProfile:
    """Per-city vulnerability profile."""
    city: str
    flood_rainfall_threshold_mm: float  # 3-day cumulative trigger
    heatwave_threshold_c: float
    primary_risks: List[str]
    terrain_notes: str
    drainage_rating: str  # "poor", "moderate", "good"
    elevation_m: float
    nearby_rivers: List[str] = field(default_factory=list)


SENSITIVITY_MATRIX: Dict[str, LocationProfile] = {
    "Karachi": LocationProfile(
        city="Karachi", flood_rainfall_threshold_mm=25.0, heatwave_threshold_c=42.0,
        primary_risks=["urban flooding", "coastal storm surge", "heatwave"],
        terrain_notes="Flat coastal city with extremely poor drainage infrastructure",
        drainage_rating="poor", elevation_m=8, nearby_rivers=["Malir", "Lyari"],
    ),
    "Lahore": LocationProfile(
        city="Lahore", flood_rainfall_threshold_mm=40.0, heatwave_threshold_c=44.0,
        primary_risks=["urban flooding", "heatwave", "smog"],
        terrain_notes="Flat alluvial plain, moderate drainage, dense urban sprawl",
        drainage_rating="moderate", elevation_m=217, nearby_rivers=["Ravi"],
    ),
    "Islamabad": LocationProfile(
        city="Islamabad", flood_rainfall_threshold_mm=55.0, heatwave_threshold_c=42.0,
        primary_risks=["hill torrents", "landslides", "flash floods"],
        terrain_notes="Margalla Hills foothills; slope runoff accelerates flooding",
        drainage_rating="good", elevation_m=507, nearby_rivers=["Kurang", "Soan"],
    ),
    "Rawalpindi": LocationProfile(
        city="Rawalpindi", flood_rainfall_threshold_mm=45.0, heatwave_threshold_c=43.0,
        primary_risks=["flash floods", "nullah overflow", "urban flooding"],
        terrain_notes="Lies in Nullah Lai floodplain; extreme flash flood risk",
        drainage_rating="poor", elevation_m=508, nearby_rivers=["Nullah Lai", "Soan"],
    ),
    "Peshawar": LocationProfile(
        city="Peshawar", flood_rainfall_threshold_mm=40.0, heatwave_threshold_c=44.0,
        primary_risks=["river flooding", "flash floods", "heatwave"],
        terrain_notes="Kabul River proximity; receives Afghan runoff",
        drainage_rating="moderate", elevation_m=331, nearby_rivers=["Kabul", "Bara"],
    ),
    "Quetta": LocationProfile(
        city="Quetta", flood_rainfall_threshold_mm=20.0, heatwave_threshold_c=40.0,
        primary_risks=["flash floods", "earthquake", "drought"],
        terrain_notes="Arid valley surrounded by mountains; flash flood channels",
        drainage_rating="poor", elevation_m=1680, nearby_rivers=["Bolan"],
    ),
    "Multan": LocationProfile(
        city="Multan", flood_rainfall_threshold_mm=35.0, heatwave_threshold_c=48.0,
        primary_risks=["extreme heat", "river flooding", "dust storms"],
        terrain_notes="Southern Punjab heat belt; near Chenab river system",
        drainage_rating="moderate", elevation_m=122, nearby_rivers=["Chenab"],
    ),
    "Hyderabad": LocationProfile(
        city="Hyderabad", flood_rainfall_threshold_mm=25.0, heatwave_threshold_c=45.0,
        primary_risks=["urban flooding", "heatwave", "river flooding"],
        terrain_notes="Indus River bank city; flat terrain, poor drainage",
        drainage_rating="poor", elevation_m=13, nearby_rivers=["Indus"],
    ),
    "Sukkur": LocationProfile(
        city="Sukkur", flood_rainfall_threshold_mm=20.0, heatwave_threshold_c=48.0,
        primary_risks=["extreme heat", "Indus flooding", "barrage overflow"],
        terrain_notes="Sukkur Barrage controls Indus flow; extreme summer heat",
        drainage_rating="moderate", elevation_m=66, nearby_rivers=["Indus"],
    ),
    "Faisalabad": LocationProfile(
        city="Faisalabad", flood_rainfall_threshold_mm=40.0, heatwave_threshold_c=45.0,
        primary_risks=["urban flooding", "heatwave", "canal overflow"],
        terrain_notes="Industrial city on flat plain with canal network",
        drainage_rating="moderate", elevation_m=184, nearby_rivers=["Chenab", "Ravi"],
    ),
}

# Default profile for cities not in the matrix
DEFAULT_PROFILE = LocationProfile(
    city="Unknown", flood_rainfall_threshold_mm=35.0, heatwave_threshold_c=43.0,
    primary_risks=["flooding", "heatwave"],
    terrain_notes="Standard Pakistan city profile",
    drainage_rating="moderate", elevation_m=200,
)


def get_location_profile(city: str) -> LocationProfile:
    """Get the sensitivity profile for a city, or default."""
    for key, profile in SENSITIVITY_MATRIX.items():
        if key.lower() == city.lower():
            return profile
    # Return default with city name set
    default = LocationProfile(
        city=city,
        flood_rainfall_threshold_mm=DEFAULT_PROFILE.flood_rainfall_threshold_mm,
        heatwave_threshold_c=DEFAULT_PROFILE.heatwave_threshold_c,
        primary_risks=DEFAULT_PROFILE.primary_risks.copy(),
        terrain_notes=DEFAULT_PROFILE.terrain_notes,
        drainage_rating=DEFAULT_PROFILE.drainage_rating,
        elevation_m=DEFAULT_PROFILE.elevation_m,
    )
    return default


@dataclass
class WeatherSnapshot:
    """Current + forecast weather data for risk analysis."""
    city: str
    current_temp_c: Optional[float] = None
    current_humidity: Optional[float] = None
    current_wind_kmh: Optional[float] = None
    current_condition: str = ""
    forecast_3day_rain_mm: float = 0.0
    forecast_3day_max_temp: float = 0.0
    forecast_7day_rain_mm: float = 0.0
    daily_forecast: List[dict] = field(default_factory=list)


@dataclass
class HistoricalContext:
    """6-month historical weather context for comparison."""
    city: str
    avg_monthly_rainfall_mm: float = 0.0
    max_monthly_rainfall_mm: float = 0.0
    avg_monthly_temp_c: float = 0.0
    max_recorded_temp_c: float = 0.0
    total_6month_rainfall_mm: float = 0.0
    monthly_breakdown: List[dict] = field(default_factory=list)


@dataclass
class RiskContext:
    """Complete risk context assembled for the LLM."""
    city: str
    profile: LocationProfile
    weather: WeatherSnapshot
    history: HistoricalContext
    risk_score: float = 0.0  # 0-100
    risk_factors: List[str] = field(default_factory=list)
    comparison_notes: List[str] = field(default_factory=list)


class ContextualRiskEngine:
    """
    Fetches current + historical data and compares against
    the Location Sensitivity Matrix to build rich risk context.
    """

    async def build_risk_context(self, city: str) -> RiskContext:
        """Build complete risk context for a city."""
        coords = self._get_coords(city)
        if not coords:
            raise ValueError(f"Unknown city: {city}")

        lat, lon = coords
        profile = get_location_profile(city)

        weather, history = await asyncio.gather(
            self._fetch_current_weather(city, lat, lon),
            self._fetch_6month_history(city, lat, lon),
        )

        risk_score, risk_factors = self._calculate_risk(profile, weather, history)
        comparison_notes = self._generate_comparisons(profile, weather, history)

        return RiskContext(
            city=city, profile=profile, weather=weather, history=history,
            risk_score=risk_score, risk_factors=risk_factors,
            comparison_notes=comparison_notes,
        )

    def _get_coords(self, city: str) -> Optional[Tuple[float, float]]:
        for name, coords in PAKISTAN_CITIES.items():
            if name.lower() == city.lower():
                return coords
        return None

    async def _fetch_current_weather(self, city: str, lat: float, lon: float) -> WeatherSnapshot:
        """Fetch current weather + 7-day forecast."""
        params = {
            "latitude": lat, "longitude": lon,
            "current": "temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code",
            "daily": "temperature_2m_max,temperature_2m_min,precipitation_sum",
            "timezone": "Asia/Karachi", "forecast_days": 7,
        }
        try:
            async with httpx.AsyncClient(timeout=15) as client:
                resp = await client.get(OPEN_METEO_FORECAST_URL, params=params)
                data = resp.json()

            current = data.get("current", {})
            daily = data.get("daily", {})
            precip = daily.get("precipitation_sum", [])
            temps = daily.get("temperature_2m_max", [])

            rain_3d = sum(p or 0 for p in precip[:3])
            rain_7d = sum(p or 0 for p in precip[:7])
            max_temp_3d = max(temps[:3]) if temps[:3] else 0

            forecasts = []
            for i, d in enumerate(daily.get("time", [])):
                forecasts.append({
                    "date": d,
                    "temp_max": temps[i] if i < len(temps) else None,
                    "temp_min": daily.get("temperature_2m_min", [None] * 7)[i] if i < len(daily.get("temperature_2m_min", [])) else None,
                    "rain_mm": precip[i] if i < len(precip) else None,
                })

            return WeatherSnapshot(
                city=city,
                current_temp_c=current.get("temperature_2m"),
                current_humidity=current.get("relative_humidity_2m"),
                current_wind_kmh=current.get("wind_speed_10m"),
                forecast_3day_rain_mm=rain_3d,
                forecast_3day_max_temp=max_temp_3d,
                forecast_7day_rain_mm=rain_7d,
                daily_forecast=forecasts,
            )
        except Exception as e:
            logger.error(f"Failed to fetch weather for {city}: {e}")
            return WeatherSnapshot(city=city)

    async def _fetch_6month_history(self, city: str, lat: float, lon: float) -> HistoricalContext:
        """Fetch 6-month historical weather data from Open-Meteo Archive."""
        end_date = date.today() - timedelta(days=2)
        start_date = end_date - timedelta(days=180)

        params = {
            "latitude": lat, "longitude": lon,
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "daily": "precipitation_sum,temperature_2m_max",
            "timezone": "Asia/Karachi",
        }
        try:
            async with httpx.AsyncClient(timeout=30) as client:
                resp = await client.get(OPEN_METEO_ARCHIVE_URL, params=params)
                data = resp.json()

            daily = data.get("daily", {})
            precip = [p or 0 for p in daily.get("precipitation_sum", [])]
            temps = [t or 0 for t in daily.get("temperature_2m_max", [])]
            dates = daily.get("time", [])

            total_rain = sum(precip)
            max_temp = max(temps) if temps else 0
            avg_temp = sum(temps) / len(temps) if temps else 0

            # Monthly breakdown
            monthly = {}
            for i, d in enumerate(dates):
                month_key = d[:7]  # "YYYY-MM"
                if month_key not in monthly:
                    monthly[month_key] = {"rain": [], "temps": []}
                monthly[month_key]["rain"].append(precip[i] if i < len(precip) else 0)
                monthly[month_key]["temps"].append(temps[i] if i < len(temps) else 0)

            monthly_data = []
            monthly_rains = []
            for month, vals in sorted(monthly.items()):
                m_rain = sum(vals["rain"])
                m_avg_temp = sum(vals["temps"]) / len(vals["temps"]) if vals["temps"] else 0
                monthly_rains.append(m_rain)
                monthly_data.append({
                    "month": month, "total_rain_mm": round(m_rain, 1),
                    "avg_max_temp_c": round(m_avg_temp, 1),
                })

            avg_monthly_rain = sum(monthly_rains) / len(monthly_rains) if monthly_rains else 0

            return HistoricalContext(
                city=city,
                avg_monthly_rainfall_mm=round(avg_monthly_rain, 1),
                max_monthly_rainfall_mm=round(max(monthly_rains) if monthly_rains else 0, 1),
                avg_monthly_temp_c=round(avg_temp, 1),
                max_recorded_temp_c=round(max_temp, 1),
                total_6month_rainfall_mm=round(total_rain, 1),
                monthly_breakdown=monthly_data,
            )
        except Exception as e:
            logger.error(f"Failed to fetch 6-month history for {city}: {e}")
            return HistoricalContext(city=city)

    def _calculate_risk(
        self, profile: LocationProfile, weather: WeatherSnapshot, history: HistoricalContext
    ) -> Tuple[float, List[str]]:
        """Calculate a 0-100 risk score with contributing factors."""
        score = 0.0
        factors = []

        # ── Flood risk component (0-50 points) ──
        rain_ratio = weather.forecast_3day_rain_mm / max(profile.flood_rainfall_threshold_mm, 1)
        if rain_ratio > 1.5:
            score += 45
            factors.append(f"CRITICAL: 3-day rainfall ({weather.forecast_3day_rain_mm:.0f}mm) is {rain_ratio:.1f}x the threshold ({profile.flood_rainfall_threshold_mm}mm)")
        elif rain_ratio > 1.0:
            score += 30
            factors.append(f"HIGH: 3-day rainfall ({weather.forecast_3day_rain_mm:.0f}mm) exceeds threshold ({profile.flood_rainfall_threshold_mm}mm)")
        elif rain_ratio > 0.6:
            score += 15
            factors.append(f"MODERATE: 3-day rainfall approaching threshold ({weather.forecast_3day_rain_mm:.0f}mm / {profile.flood_rainfall_threshold_mm}mm)")

        # Drainage penalty
        drainage_penalty = {"poor": 10, "moderate": 5, "good": 0}
        d_penalty = drainage_penalty.get(profile.drainage_rating, 5)
        if weather.forecast_3day_rain_mm > 10 and d_penalty > 0:
            score += d_penalty
            factors.append(f"Drainage: {profile.drainage_rating} ({profile.terrain_notes})")

        # ── Heat risk component (0-30 points) ──
        if weather.forecast_3day_max_temp > 0:
            heat_ratio = weather.forecast_3day_max_temp / max(profile.heatwave_threshold_c, 1)
            if heat_ratio > 1.0:
                score += 25
                factors.append(f"HEATWAVE: Max temp ({weather.forecast_3day_max_temp:.1f}°C) exceeds threshold ({profile.heatwave_threshold_c}°C)")
            elif heat_ratio > 0.9:
                score += 12
                factors.append(f"Heat advisory: Temp approaching threshold ({weather.forecast_3day_max_temp:.1f}°C / {profile.heatwave_threshold_c}°C)")

        # ── Historical anomaly component (0-20 points) ──
        if history.avg_monthly_rainfall_mm > 0 and weather.forecast_7day_rain_mm > 0:
            weekly_avg = history.avg_monthly_rainfall_mm / 4.3
            if weather.forecast_7day_rain_mm > weekly_avg * 2:
                score += 15
                factors.append(f"ANOMALY: 7-day forecast ({weather.forecast_7day_rain_mm:.0f}mm) is {weather.forecast_7day_rain_mm / weekly_avg:.1f}x the weekly average ({weekly_avg:.0f}mm)")

        return min(score, 100), factors

    def _generate_comparisons(
        self, profile: LocationProfile, weather: WeatherSnapshot, history: HistoricalContext
    ) -> List[str]:
        """Generate human-readable comparison notes."""
        notes = []

        if history.avg_monthly_rainfall_mm > 0:
            notes.append(
                f"6-month avg rainfall: {history.avg_monthly_rainfall_mm:.0f}mm/month "
                f"(peak: {history.max_monthly_rainfall_mm:.0f}mm)"
            )

        if weather.forecast_3day_rain_mm > 0:
            notes.append(
                f"Upcoming 3-day rain ({weather.forecast_3day_rain_mm:.0f}mm) vs "
                f"{profile.city}'s flood threshold ({profile.flood_rainfall_threshold_mm}mm)"
            )

        if profile.nearby_rivers:
            notes.append(f"River proximity: {', '.join(profile.nearby_rivers)}")

        if history.max_recorded_temp_c > 0:
            notes.append(f"6-month max recorded temp: {history.max_recorded_temp_c:.1f}°C")

        return notes


def format_risk_context_for_llm(ctx: RiskContext) -> str:
    """Format the risk context into a structured string for the LLM system prompt."""
    lines = [
        f"═══ RISK CONTEXT FOR {ctx.city.upper()} ═══",
        f"Risk Score: {ctx.risk_score:.0f}/100",
        "",
        "── Location Profile ──",
        f"  Elevation: {ctx.profile.elevation_m}m | Drainage: {ctx.profile.drainage_rating}",
        f"  Terrain: {ctx.profile.terrain_notes}",
        f"  Primary risks: {', '.join(ctx.profile.primary_risks)}",
        f"  Flood threshold: {ctx.profile.flood_rainfall_threshold_mm}mm (3-day)",
        f"  Heatwave threshold: {ctx.profile.heatwave_threshold_c}°C",
    ]

    if ctx.profile.nearby_rivers:
        lines.append(f"  Rivers: {', '.join(ctx.profile.nearby_rivers)}")

    lines += [
        "",
        "── Current Weather ──",
        f"  Temperature: {ctx.weather.current_temp_c}°C | Humidity: {ctx.weather.current_humidity}%",
        f"  Wind: {ctx.weather.current_wind_kmh} km/h",
        "",
        "── Forecast ──",
        f"  3-day rainfall: {ctx.weather.forecast_3day_rain_mm:.1f}mm",
        f"  3-day max temp: {ctx.weather.forecast_3day_max_temp:.1f}°C",
        f"  7-day rainfall: {ctx.weather.forecast_7day_rain_mm:.1f}mm",
    ]

    if ctx.weather.daily_forecast:
        lines.append("  Daily breakdown:")
        for d in ctx.weather.daily_forecast[:5]:
            lines.append(f"    {d['date']}: {d.get('temp_max', '?')}°C max, {d.get('rain_mm', '?')}mm rain")

    lines += [
        "",
        "── 6-Month Historical ──",
        f"  Avg monthly rain: {ctx.history.avg_monthly_rainfall_mm}mm",
        f"  Peak monthly rain: {ctx.history.max_monthly_rainfall_mm}mm",
        f"  Avg max temp: {ctx.history.avg_monthly_temp_c}°C",
        f"  Max recorded temp: {ctx.history.max_recorded_temp_c}°C",
        f"  Total 6-month rain: {ctx.history.total_6month_rainfall_mm}mm",
    ]

    if ctx.risk_factors:
        lines += ["", "── Active Risk Factors ──"]
        for f in ctx.risk_factors:
            lines.append(f"  ⚠ {f}")

    if ctx.comparison_notes:
        lines += ["", "── Comparisons ──"]
        for n in ctx.comparison_notes:
            lines.append(f"  • {n}")

    return "\n".join(lines)
