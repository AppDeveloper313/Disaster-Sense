"""Main data fetcher module for DisasterSense."""

import asyncio
import json
import logging
from datetime import datetime, timezone
from typing import List, Optional

try:
    from .config import PAKISTAN_CITIES
    from .flood_analyzer import FloodAnalyzer
    from .models import DisasterSenseResult, FloodRiskAlert
    from .weather_fetcher import WeatherFetcher, WeatherFetchError
except ImportError:
    from config import PAKISTAN_CITIES
    from flood_analyzer import FloodAnalyzer
    from models import DisasterSenseResult, FloodRiskAlert
    from weather_fetcher import WeatherFetcher, WeatherFetchError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class DisasterSenseDataFetcher:
    """
    Main data fetcher for DisasterSense.
    
    Fetches weather data for Pakistani cities and analyzes flood risk.
    """
    
    def __init__(self, cities: Optional[dict] = None):
        """
        Initialize the data fetcher.
        
        Args:
            cities: Dictionary of city names to (lat, lon) tuples.
                   Defaults to PAKISTAN_CITIES.
        """
        self.cities = cities or PAKISTAN_CITIES
        self.analyzer = FloodAnalyzer()
    
    async def fetch_and_analyze(self) -> DisasterSenseResult:
        """
        Fetch weather data for all cities and analyze flood risk.

        Uses batch API calls — only 2 HTTP requests for all cities combined,
        eliminating the 429 Too Many Requests errors from the old per-city approach.
        """
        timestamp = datetime.now(timezone.utc).isoformat()
        alerts: List[FloodRiskAlert] = []
        errors: List[str] = []

        async with WeatherFetcher() as fetcher:
            try:
                forecasts, historicals = await asyncio.gather(
                    fetcher.fetch_all_forecasts(self.cities),
                    fetcher.fetch_all_historical(self.cities),
                )
            except WeatherFetchError as e:
                error_msg = f"Batch weather fetch failed: {e}"
                logger.error(error_msg)
                errors.append(error_msg)
                return DisasterSenseResult(
                    timestamp=timestamp,
                    cities_analyzed=0,
                    alerts=[],
                    errors=errors,
                )

            for city in self.cities:
                forecast = forecasts.get(city)
                historical = historicals.get(city)

                if forecast is None or historical is None:
                    errors.append(f"Missing data for {city}")
                    continue

                try:
                    alert = self.analyzer.analyze(forecast, historical)
                    alerts.append(alert)
                    logger.info(
                        f"{city}: Risk={alert.risk_level.value}, "
                        f"Rainfall={alert.cumulative_rainfall_3day:.1f}mm"
                    )
                except Exception as e:
                    error_msg = f"Analysis error for {city}: {e}"
                    logger.error(error_msg)
                    errors.append(error_msg)

        return DisasterSenseResult(
            timestamp=timestamp,
            cities_analyzed=len(alerts),
            alerts=alerts,
            errors=errors,
        )
    
    async def fetch_and_analyze_json(self) -> str:
        """
        Fetch and analyze, returning results as JSON string.
        
        Returns:
            JSON string with analysis results
        """
        result = await self.fetch_and_analyze()
        return json.dumps(result.to_dict(), indent=2)
    
    def run(self) -> DisasterSenseResult:
        """
        Synchronous wrapper to run the async fetch and analyze.
        
        Returns:
            DisasterSenseResult with alerts for all cities
        """
        return asyncio.run(self.fetch_and_analyze())
    
    def run_json(self) -> str:
        """
        Synchronous wrapper returning JSON results.
        
        Returns:
            JSON string with analysis results
        """
        return asyncio.run(self.fetch_and_analyze_json())


def main():
    """Main entry point for running the data fetcher."""
    import sys
    if sys.stdout.encoding.lower() != 'utf-8':
        try:
            sys.stdout.reconfigure(encoding='utf-8')
        except AttributeError:
            pass
            
    print("DisasterSense Data Fetcher")
    print("=" * 50)
    print("Fetching weather data for Pakistani cities...")
    print()
    
    fetcher = DisasterSenseDataFetcher()
    result = fetcher.run()
    
    print("\n" + "=" * 50)
    print("FLOOD RISK ASSESSMENT RESULTS")
    print("=" * 50 + "\n")
    
    for alert in result.alerts:
        status_icon = "🔴" if alert.alert_triggered else ("🟡" if alert.risk_level.value == "medium" else "🟢")
        print(f"{status_icon} {alert.city}")
        print(f"   Risk Level: {alert.risk_level.value.upper()}")
        print(f"   3-Day Rainfall: {alert.cumulative_rainfall_3day:.1f}mm")
        print(f"   {alert.forecast_summary}")
        print(f"   → {alert.recommendation}")
        print()
    
    if result.errors:
        print("⚠️ Errors encountered:")
        for error in result.errors:
            print(f"   - {error}")
    
    print("\n" + "=" * 50)
    print("JSON Output:")
    print("=" * 50)
    print(json.dumps(result.to_dict(), indent=2))


if __name__ == "__main__":
    main()
