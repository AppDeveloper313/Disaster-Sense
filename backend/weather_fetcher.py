"""Weather data fetcher using Open-Meteo APIs — batch edition.

Instead of making one request per city, we use Open-Meteo's multi-location
(array) API to fetch all cities in ONE request each for forecast and
historical data, dramatically reducing call count and eliminating 429 errors.
"""

import asyncio
import logging
from datetime import date, timedelta
from typing import Dict, List, Optional, Tuple

import httpx

try:
    from .config import (
        OPEN_METEO_ARCHIVE_URL,
        OPEN_METEO_FORECAST_URL,
        REQUEST_TIMEOUT,
        MAX_RETRIES,
        RETRY_DELAY,
    )
    from .models import DailyForecast, HistoricalRainfall, WeatherForecast
except ImportError:
    from config import (
        OPEN_METEO_ARCHIVE_URL,
        OPEN_METEO_FORECAST_URL,
        REQUEST_TIMEOUT,
        MAX_RETRIES,
        RETRY_DELAY,
    )
    from models import DailyForecast, HistoricalRainfall, WeatherForecast

logger = logging.getLogger(__name__)


class WeatherFetchError(Exception):
    """Custom exception for weather fetch errors."""
    pass


class WeatherFetcher:
    """Fetches weather data from Open-Meteo APIs using batch requests."""

    def __init__(self):
        self.client: Optional[httpx.AsyncClient] = None

    async def __aenter__(self):
        self.client = httpx.AsyncClient(timeout=REQUEST_TIMEOUT)
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.client:
            await self.client.aclose()

    async def _fetch_with_retry(self, url: str, params: dict) -> dict | list:
        """Fetch data with retry logic, handles both dict and list responses."""
        last_error = None

        for attempt in range(MAX_RETRIES):
            try:
                response = await self.client.get(url, params=params)
                response.raise_for_status()
                return response.json()
            except httpx.HTTPStatusError as e:
                last_error = e
                logger.warning(f"HTTP error on attempt {attempt + 1}: {e}")
            except httpx.RequestError as e:
                last_error = e
                logger.warning(f"Request error on attempt {attempt + 1}: {repr(e)}")

            if attempt < MAX_RETRIES - 1:
                await asyncio.sleep(RETRY_DELAY * (attempt + 1))

        raise WeatherFetchError(f"Failed after {MAX_RETRIES} attempts: {last_error}")

    async def fetch_all_forecasts(
        self, cities: Dict[str, Tuple[float, float]]
    ) -> Dict[str, WeatherForecast]:
        """
        Fetch 7-day forecast for ALL cities in a single batched API request.

        Open-Meteo supports comma-separated latitude/longitude arrays,
        returning a JSON array with one entry per location.
        """
        city_names = list(cities.keys())
        lats = [cities[c][0] for c in city_names]
        lons = [cities[c][1] for c in city_names]

        params = {
            "latitude": ",".join(str(l) for l in lats),
            "longitude": ",".join(str(l) for l in lons),
            "daily": "temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max",
            "timezone": "Asia/Karachi",
            "forecast_days": 7,
        }

        logger.info(f"Fetching forecast for {len(city_names)} cities in one batch request.")
        try:
            data = await self._fetch_with_retry(OPEN_METEO_FORECAST_URL, params)
            # Single city returns dict; multiple returns list
            if isinstance(data, dict):
                data = [data]

            forecasts: Dict[str, WeatherForecast] = {}
            for i, city in enumerate(city_names):
                if i >= len(data):
                    break
                entry = data[i]
                daily = entry.get("daily", {})
                dates = daily.get("time", [])
                temp_max = daily.get("temperature_2m_max", [])
                temp_min = daily.get("temperature_2m_min", [])
                precip = daily.get("precipitation_sum", [])
                precip_prob = daily.get("precipitation_probability_max", [])

                daily_forecasts = []
                for j, date_str in enumerate(dates):
                    daily_forecasts.append(DailyForecast(
                        date=date.fromisoformat(date_str),
                        temp_max=temp_max[j] if j < len(temp_max) else 0.0,
                        temp_min=temp_min[j] if j < len(temp_min) else 0.0,
                        precipitation=precip[j] if j < len(precip) and precip[j] is not None else 0.0,
                        precipitation_probability=precip_prob[j] if j < len(precip_prob) else None,
                    ))

                forecasts[city] = WeatherForecast(
                    city=city,
                    latitude=lats[i],
                    longitude=lons[i],
                    daily_forecasts=daily_forecasts,
                )
            return forecasts

        except Exception as e:
            logger.error(f"Batch forecast fetch failed: {e}")
            raise WeatherFetchError(f"Batch forecast fetch failed: {e}")

    async def fetch_all_historical(
        self, cities: Dict[str, Tuple[float, float]], days: int = 7
    ) -> Dict[str, HistoricalRainfall]:
        """
        Fetch historical rainfall for ALL cities in a single batched API request.
        """
        city_names = list(cities.keys())
        lats = [cities[c][0] for c in city_names]
        lons = [cities[c][1] for c in city_names]

        end_date = date.today() - timedelta(days=1)
        start_date = end_date - timedelta(days=days - 1)

        params = {
            "latitude": ",".join(str(l) for l in lats),
            "longitude": ",".join(str(l) for l in lons),
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "daily": "precipitation_sum",
            "timezone": "Asia/Karachi",
        }

        logger.info(f"Fetching historical rainfall for {len(city_names)} cities in one batch request.")
        try:
            data = await self._fetch_with_retry(OPEN_METEO_ARCHIVE_URL, params)
            if isinstance(data, dict):
                data = [data]

            historical: Dict[str, HistoricalRainfall] = {}
            for i, city in enumerate(city_names):
                if i >= len(data):
                    break
                entry = data[i]
                daily = entry.get("daily", {})
                precip = daily.get("precipitation_sum", [])
                rainfall = [p if p is not None else 0.0 for p in precip]

                historical[city] = HistoricalRainfall(
                    city=city,
                    latitude=lats[i],
                    longitude=lons[i],
                    start_date=start_date,
                    end_date=end_date,
                    daily_rainfall=rainfall,
                )
            return historical

        except Exception as e:
            logger.error(f"Batch historical fetch failed: {e}")
            raise WeatherFetchError(f"Batch historical fetch failed: {e}")

    # ── Legacy per-city helpers (kept for compatibility) ──────────────────────

    async def fetch_forecast(
        self, city: str, latitude: float, longitude: float
    ) -> WeatherForecast:
        result = await self.fetch_all_forecasts({city: (latitude, longitude)})
        return result[city]

    async def fetch_historical_rainfall(
        self, city: str, latitude: float, longitude: float, days: int = 7
    ) -> HistoricalRainfall:
        result = await self.fetch_all_historical({city: (latitude, longitude)}, days=days)
        return result[city]

    async def fetch_city_weather_data(
        self, city: str, latitude: float, longitude: float
    ) -> Tuple[WeatherForecast, HistoricalRainfall]:
        forecast_task = self.fetch_forecast(city, latitude, longitude)
        historical_task = self.fetch_historical_rainfall(city, latitude, longitude)
        forecast, historical = await asyncio.gather(forecast_task, historical_task)
        return forecast, historical
