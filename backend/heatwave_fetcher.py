import asyncio
from datetime import datetime, timezone
from typing import List, Optional
import logging

try:
    from .config import PAKISTAN_CITIES
    from .models import HeatwaveRiskAlert, HeatwaveSenseResult, RiskLevel, WeatherForecast
    from .weather_fetcher import WeatherFetcher
except ImportError:
    from config import PAKISTAN_CITIES
    from models import HeatwaveRiskAlert, HeatwaveSenseResult, RiskLevel, WeatherForecast
    from weather_fetcher import WeatherFetcher

logger = logging.getLogger(__name__)

class HeatwaveAnalyzer:
    """Analyzes weather forecast for heatwave risk."""
    
    # Thresholds for Pakistan (approximate)
    HIGH_RISK_THRESHOLD = 40.0
    MEDIUM_RISK_THRESHOLD = 36.0
    
    def analyze(self, forecast: WeatherForecast) -> HeatwaveRiskAlert:
        # Find the maximum temperature over the next 3 days
        temps = [d.temp_max for d in forecast.daily_forecasts[:3]]
        max_temp = max(temps) if temps else 0.0
        
        if max_temp >= self.HIGH_RISK_THRESHOLD:
            risk_level = RiskLevel.HIGH
            summary = f"Extreme heat expected. Maximum temperature projected to reach {max_temp:.1f}°C."
            recommendation = "Stay indoors during peak hours, stay hydrated, and avoid strenuous outdoor activities."
            alert_triggered = True
        elif max_temp >= self.MEDIUM_RISK_THRESHOLD:
            risk_level = RiskLevel.MEDIUM
            summary = f"Elevated temperatures expected. Maximum temperature projected to reach {max_temp:.1f}°C."
            recommendation = "Drink plenty of water and wear light, loose-fitting clothing."
            alert_triggered = False
        else:
            risk_level = RiskLevel.LOW
            summary = f"Normal temperature ranges. Maximum temperature projected at {max_temp:.1f}°C."
            recommendation = "No special precautions needed."
            alert_triggered = False
            
        return HeatwaveRiskAlert(
            city=forecast.city,
            risk_level=risk_level,
            max_temperature=max_temp,
            forecast_summary=summary,
            alert_triggered=alert_triggered,
            recommendation=recommendation
        )

class HeatwaveDataFetcher:
    """Fetches weather data and analyzes heatwave risk."""
    
    def __init__(self, cities: Optional[dict] = None):
        self.cities = cities or PAKISTAN_CITIES
        self.analyzer = HeatwaveAnalyzer()
        
    async def fetch_and_analyze(self) -> HeatwaveSenseResult:
        timestamp = datetime.now(timezone.utc).isoformat()
        alerts: List[HeatwaveRiskAlert] = []
        errors: List[str] = []
        
        async with WeatherFetcher() as fetcher:
            tasks = []
            city_names = []
            
            for city, (lat, lon) in self.cities.items():
                task = fetcher.fetch_forecast(city, lat, lon)
                tasks.append(task)
                city_names.append(city)
                
            results = await asyncio.gather(*tasks, return_exceptions=True)
            
            for city, result in zip(city_names, results):
                if isinstance(result, Exception):
                    errors.append(f"Failed to fetch heatwave data for {city}: {result}")
                    continue
                    
                try:
                    alert = self.analyzer.analyze(result)
                    alerts.append(alert)
                except Exception as e:
                    errors.append(f"Heatwave analysis error for {city}: {e}")
                    
        return HeatwaveSenseResult(
            timestamp=timestamp,
            cities_analyzed=len(alerts),
            alerts=alerts,
            errors=errors
        )
