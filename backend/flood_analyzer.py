"""Flood risk analysis module."""

import logging
from typing import Tuple

try:
    from .config import FLOOD_THRESHOLDS
    from .models import (
        FloodRiskAlert,
        HistoricalRainfall,
        RiskLevel,
        WeatherForecast,
    )
except ImportError:
    from config import FLOOD_THRESHOLDS
    from models import (
        FloodRiskAlert,
        HistoricalRainfall,
        RiskLevel,
        WeatherForecast,
    )

logger = logging.getLogger(__name__)


class FloodAnalyzer:
    """Analyzes weather data to assess flood risk."""
    
    def __init__(self, thresholds=FLOOD_THRESHOLDS):
        self.thresholds = thresholds
    
    def calculate_risk_level(self, cumulative_rainfall: float) -> RiskLevel:
        """
        Determine flood risk level based on 3-day cumulative rainfall.
        
        Args:
            cumulative_rainfall: Total rainfall in mm over 3 days
            
        Returns:
            RiskLevel enum value
        """
        if cumulative_rainfall <= self.thresholds.LOW_MAX:
            return RiskLevel.LOW
        elif cumulative_rainfall <= self.thresholds.MEDIUM_MAX:
            return RiskLevel.MEDIUM
        else:
            return RiskLevel.HIGH
    
    def generate_forecast_summary(
        self, forecast: WeatherForecast, historical: HistoricalRainfall
    ) -> str:
        """
        Generate a human-readable forecast summary.
        
        Args:
            forecast: 7-day weather forecast
            historical: Historical rainfall data
            
        Returns:
            Summary string
        """
        if not forecast.daily_forecasts:
            return "No forecast data available."
        
        # Get upcoming 3-day forecast precipitation
        upcoming_precip = sum(
            d.precipitation for d in forecast.daily_forecasts[:3]
        )
        
        # Get temperature range for next 3 days
        temps = [(d.temp_min, d.temp_max) for d in forecast.daily_forecasts[:3]]
        min_temp = min(t[0] for t in temps) if temps else 0
        max_temp = max(t[1] for t in temps) if temps else 0
        
        # Recent rainfall
        recent_rainfall = historical.cumulative_rainfall(3)
        
        summary_parts = [
            f"Recent 3-day rainfall: {recent_rainfall:.1f}mm.",
            f"Expected next 3 days: {upcoming_precip:.1f}mm precipitation.",
            f"Temperature range: {min_temp:.0f}°C to {max_temp:.0f}°C.",
        ]
        
        return " ".join(summary_parts)
    
    def get_recommendation(self, risk_level: RiskLevel, city: str) -> str:
        """
        Get safety recommendation based on risk level.
        
        Args:
            risk_level: Assessed flood risk level
            city: City name
            
        Returns:
            Recommendation string
        """
        recommendations = {
            RiskLevel.LOW: f"Normal conditions in {city}. No immediate flood risk.",
            RiskLevel.MEDIUM: (
                f"Elevated flood risk in {city}. Monitor weather updates closely. "
                "Avoid low-lying areas during heavy rainfall."
            ),
            RiskLevel.HIGH: (
                f"HIGH FLOOD RISK in {city}! Heavy rainfall detected. "
                "Avoid flood-prone areas. Prepare emergency supplies. "
                "Follow local authority instructions."
            ),
        }
        return recommendations.get(risk_level, "Unable to assess risk.")
    
    def analyze(
        self, forecast: WeatherForecast, historical: HistoricalRainfall
    ) -> FloodRiskAlert:
        """
        Perform complete flood risk analysis for a city.
        
        Args:
            forecast: 7-day weather forecast
            historical: Historical rainfall data
            
        Returns:
            FloodRiskAlert with complete assessment
        """
        city = forecast.city
        
        # Calculate 3-day cumulative rainfall from historical data
        cumulative_rainfall = historical.cumulative_rainfall(3)
        
        # Determine risk level
        risk_level = self.calculate_risk_level(cumulative_rainfall)
        
        # Generate summary and recommendation
        summary = self.generate_forecast_summary(forecast, historical)
        recommendation = self.get_recommendation(risk_level, city)
        
        # Trigger alert if risk is high (above 50mm threshold)
        alert_triggered = risk_level == RiskLevel.HIGH
        
        if alert_triggered:
            logger.warning(
                f"FLOOD ALERT: {city} - {cumulative_rainfall:.1f}mm rainfall in 3 days"
            )
        
        return FloodRiskAlert(
            city=city,
            risk_level=risk_level,
            cumulative_rainfall_3day=cumulative_rainfall,
            forecast_summary=summary,
            alert_triggered=alert_triggered,
            recommendation=recommendation,
        )
