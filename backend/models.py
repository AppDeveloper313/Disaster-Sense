"""Data models for DisasterSense."""

from dataclasses import dataclass, field
from datetime import date
from enum import Enum
from typing import List, Optional


class RiskLevel(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


@dataclass
class DailyForecast:
    """Single day weather forecast."""
    date: date
    temp_max: float  # Celsius
    temp_min: float  # Celsius
    precipitation: float  # mm
    precipitation_probability: Optional[int] = None  # percentage


@dataclass
class WeatherForecast:
    """7-day weather forecast for a city."""
    city: str
    latitude: float
    longitude: float
    daily_forecasts: List[DailyForecast] = field(default_factory=list)
    
    @property
    def total_precipitation(self) -> float:
        """Total precipitation over forecast period."""
        return sum(d.precipitation for d in self.daily_forecasts)


@dataclass
class HistoricalRainfall:
    """Historical rainfall data for a city."""
    city: str
    latitude: float
    longitude: float
    start_date: date
    end_date: date
    daily_rainfall: List[float] = field(default_factory=list)  # mm per day
    
    @property
    def total_rainfall(self) -> float:
        """Total rainfall over the period."""
        return sum(self.daily_rainfall)
    
    def cumulative_rainfall(self, days: int = 3) -> float:
        """Get cumulative rainfall for the last N days."""
        if not self.daily_rainfall:
            return 0.0
        return sum(self.daily_rainfall[-days:])


@dataclass
class FloodRiskAlert:
    """Flood risk assessment for a city."""
    city: str
    risk_level: RiskLevel
    cumulative_rainfall_3day: float  # mm
    forecast_summary: str
    alert_triggered: bool = False
    recommendation: str = ""
    
    def to_dict(self) -> dict:
        """Convert to dictionary for JSON serialization."""
        return {
            "city": self.city,
            "risk_level": self.risk_level.value,
            "cumulative_rainfall_3day_mm": round(self.cumulative_rainfall_3day, 2),
            "forecast_summary": self.forecast_summary,
            "alert_triggered": self.alert_triggered,
            "recommendation": self.recommendation,
        }


@dataclass
class DisasterSenseResult:
    """Complete result from the data fetcher."""
    timestamp: str
    cities_analyzed: int
    alerts: List[FloodRiskAlert] = field(default_factory=list)
    errors: List[str] = field(default_factory=list)
    
    def to_dict(self) -> dict:
        """Convert to dictionary for JSON serialization."""
        return {
            "timestamp": self.timestamp,
            "cities_analyzed": self.cities_analyzed,
            "alerts": [alert.to_dict() for alert in self.alerts],
            "errors": self.errors,
        }
