"""Weather data fetcher using Open-Meteo APIs."""

import asyncio
import logging
from datetime import date, datetime, timedelta
from typing import Optional, Tuple

import httpx

from .config import (
    OPEN_METEO_ARCHIVE_URL,
    OPEN_METEO_FORECAST_URL,
    REQUEST_TIMEOUT,
    MAX_RETRIES,
    RETRY_DELAY,
)
from .models import DailyForecast, HistoricalRainfall, WeatherForecast

logger = logging.getLogger(__name__)


class WeatherFetchError(Exception):
    """Custom exception for weather fetch errors."""
    pass


class WeatherFetcher:
    """Fetches weather data from Open-Meteo APIs."""
    
    def __init__(self):
        self.client: Optional[httpx.AsyncClient] = None
    
    async def __aenter__(self):
        self.client = httpx.AsyncClient(timeout=REQUEST_TIMEOUT)
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.client:
            await self.client.aclose()
    
    async def _fetch_with_retry(self, url: str, params: dict) -> dict:
        """Fetch data with retry logic."""
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
                logger.warning(f"Request error on attempt {attempt + 1}: {e}")
            
            if attempt < MAX_RETRIES - 1:
                await asyncio.sleep(RETRY_DELAY * (attempt + 1))
        
        raise WeatherFetchError(f"Failed after {MAX_RETRIES} attempts: {last_error}")
    
    async def fetch_forecast(
        self, city: str, latitude: float, longitude: float
    ) -> WeatherForecast:
        """
        Fetch 7-day weather forecast for a city.
        
        Args:
            city: City name
            latitude: City latitude
            longitude: City longitude
            
        Returns:
            WeatherForecast object with daily forecasts
        """
        params = {
            "latitude": latitude,
            "longitude": longitude,
            "daily": "temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max",
            "timezone": "Asia/Karachi",
            "forecast_days": 7,
        }
        
        try:
            data = await self._fetch_with_retry(OPEN_METEO_FORECAST_URL, params)
            
            daily = data.get("daily", {})
            dates = daily.get("time", [])
            temp_max = daily.get("temperature_2m_max", [])
            temp_min = daily.get("temperature_2m_min", [])
            precip = daily.get("precipitation_sum", [])
            precip_prob = daily.get("precipitation_probability_max", [])
            
            forecasts = []
            for i, date_str in enumerate(dates):
                forecast = DailyForecast(
                    date=date.fromisoformat(date_str),
                    temp_max=temp_max[i] if i < len(temp_max) else 0.0,
                    temp_min=temp_min[i] if i < len(temp_min) else 0.0,
                    precipitation=precip[i] if i < len(precip) and precip[i] is not None else 0.0,
                    precipitation_probability=precip_prob[i] if i < len(precip_prob) else None,
                )
                forecasts.append(forecast)
            
            return WeatherForecast(
                city=city,
                latitude=latitude,
                longitude=longitude,
                daily_forecasts=forecasts,
            )
            
        except Exception as e:
            logger.error(f"Error fetching forecast for {city}: {e}")
            raise WeatherFetchError(f"Failed to fetch forecast for {city}: {e}")
    
    async def fetch_historical_rainfall(
        self, city: str, latitude: float, longitude: float, days: int = 7
    ) -> HistoricalRainfall:
        """
        Fetch historical rainfall data for the last N days.
        
        Args:
            city: City name
            latitude: City latitude
            longitude: City longitude
            days: Number of historical days to fetch
            
        Returns:
            HistoricalRainfall object with daily rainfall data
        """
        end_date = date.today() - timedelta(days=1)  # Yesterday (archive has delay)
        start_date = end_date - timedelta(days=days - 1)
        
        params = {
            "latitude": latitude,
            "longitude": longitude,
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "daily": "precipitation_sum",
            "timezone": "Asia/Karachi",
        }
        
        try:
            data = await self._fetch_with_retry(OPEN_METEO_ARCHIVE_URL, params)
            
            daily = data.get("daily", {})
            precip = daily.get("precipitation_sum", [])
            
            # Handle None values in precipitation data
            rainfall = [p if p is not None else 0.0 for p in precip]
            
            return HistoricalRainfall(
                city=city,
                latitude=latitude,
                longitude=longitude,
                start_date=start_date,
                end_date=end_date,
                daily_rainfall=rainfall,
            )
            
        except Exception as e:
            logger.error(f"Error fetching historical data for {city}: {e}")
            raise WeatherFetchError(f"Failed to fetch historical data for {city}: {e}")
    
    async def fetch_city_weather_data(
        self, city: str, latitude: float, longitude: float
    ) -> Tuple[WeatherForecast, HistoricalRainfall]:
        """
        Fetch both forecast and historical data for a city.
        
        Args:
            city: City name
            latitude: City latitude
            longitude: City longitude
            
        Returns:
            Tuple of (WeatherForecast, HistoricalRainfall)
        """
        forecast_task = self.fetch_forecast(city, latitude, longitude)
        historical_task = self.fetch_historical_rainfall(city, latitude, longitude)
        
        forecast, historical = await asyncio.gather(forecast_task, historical_task)
        return forecast, historical
