"""Earthquake data fetcher using USGS API."""

import logging
import math
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from enum import Enum
from typing import List, Optional, Tuple

import httpx

try:
    from .config import PAKISTAN_CITIES, REQUEST_TIMEOUT, MAX_RETRIES, RETRY_DELAY
except ImportError:
    from config import PAKISTAN_CITIES, REQUEST_TIMEOUT, MAX_RETRIES, RETRY_DELAY

logger = logging.getLogger(__name__)

# USGS API endpoint
USGS_EARTHQUAKE_URL = "https://earthquake.usgs.gov/fdsnws/event/1/query"

# Pakistan bounding box
PAKISTAN_BOUNDS = {
    "minlatitude": 23,
    "maxlatitude": 37,
    "minlongitude": 60,
    "maxlongitude": 77,
}


class EarthquakeRiskLevel(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


@dataclass
class Earthquake:
    """Represents a single earthquake event."""
    id: str
    magnitude: float
    depth_km: float
    latitude: float
    longitude: float
    location_description: str
    quake_time: datetime
    
    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "magnitude": self.magnitude,
            "depth_km": self.depth_km,
            "latitude": self.latitude,
            "longitude": self.longitude,
            "location_description": self.location_description,
            "quake_time": self.quake_time.isoformat(),
        }


@dataclass
class CityEarthquakeAlert:
    """Earthquake risk alert for a city."""
    city: str
    nearest_quake: Optional[Earthquake]
    distance_km: float
    risk_level: EarthquakeRiskLevel
    alert_triggered: bool
    recommendation: str
    
    def to_dict(self) -> dict:
        return {
            "city": self.city,
            "risk_level": self.risk_level.value,
            "alert_triggered": self.alert_triggered,
            "distance_km": round(self.distance_km, 1),
            "recommendation": self.recommendation,
            "earthquake": self.nearest_quake.to_dict() if self.nearest_quake else None,
        }


@dataclass
class EarthquakeResult:
    """Complete result from earthquake fetcher."""
    timestamp: str
    total_quakes_found: int
    cities_analyzed: int
    alerts: List[CityEarthquakeAlert]
    errors: List[str]
    
    def to_dict(self) -> dict:
        return {
            "timestamp": self.timestamp,
            "total_quakes_found": self.total_quakes_found,
            "cities_analyzed": self.cities_analyzed,
            "alerts": [alert.to_dict() for alert in self.alerts],
            "errors": self.errors,
        }


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate the great-circle distance between two points on Earth.
    
    Args:
        lat1, lon1: First point coordinates (degrees)
        lat2, lon2: Second point coordinates (degrees)
        
    Returns:
        Distance in kilometers
    """
    R = 6371  # Earth's radius in km
    
    lat1_rad = math.radians(lat1)
    lat2_rad = math.radians(lat2)
    delta_lat = math.radians(lat2 - lat1)
    delta_lon = math.radians(lon2 - lon1)
    
    a = (math.sin(delta_lat / 2) ** 2 +
         math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(delta_lon / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    
    return R * c


def calculate_risk_level(magnitude: float) -> EarthquakeRiskLevel:
    """
    Determine earthquake risk level based on magnitude.
    
    Args:
        magnitude: Earthquake magnitude
        
    Returns:
        EarthquakeRiskLevel enum value
    """
    if magnitude < 4.5:
        return EarthquakeRiskLevel.LOW
    elif magnitude <= 5.5:
        return EarthquakeRiskLevel.MEDIUM
    else:
        return EarthquakeRiskLevel.HIGH


def get_recommendation(risk_level: EarthquakeRiskLevel, city: str, magnitude: Optional[float]) -> str:
    """Get safety recommendation based on risk level."""
    if magnitude is None:
        return f"No significant seismic activity detected near {city}."
    
    recommendations = {
        EarthquakeRiskLevel.LOW: (
            f"Minor seismic activity detected near {city} (M{magnitude:.1f}). "
            "No immediate action required. Stay informed."
        ),
        EarthquakeRiskLevel.MEDIUM: (
            f"Moderate earthquake activity near {city} (M{magnitude:.1f}). "
            "Review emergency plans. Secure heavy objects. Stay alert for aftershocks."
        ),
        EarthquakeRiskLevel.HIGH: (
            f"SIGNIFICANT EARTHQUAKE near {city} (M{magnitude:.1f})! "
            "Drop, Cover, Hold On if shaking. Move away from buildings after shaking stops. "
            "Expect aftershocks. Follow local emergency instructions."
        ),
    }
    return recommendations.get(risk_level, "Unable to assess risk.")


class EarthquakeFetcher:
    """Fetches earthquake data from USGS API."""
    
    def __init__(self):
        self.client: Optional[httpx.AsyncClient] = None
    
    async def __aenter__(self):
        self.client = httpx.AsyncClient(timeout=REQUEST_TIMEOUT)
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.client:
            await self.client.aclose()
    
    async def fetch_earthquakes(self, days: int = 7, min_magnitude: float = 4.0) -> List[Earthquake]:
        """
        Fetch earthquakes from USGS API for Pakistan region.
        
        Args:
            days: Number of days to look back
            min_magnitude: Minimum magnitude to fetch
            
        Returns:
            List of Earthquake objects
        """
        end_time = datetime.now(timezone.utc)
        start_time = end_time - timedelta(days=days)
        
        params = {
            "format": "geojson",
            "starttime": start_time.strftime("%Y-%m-%d"),
            "endtime": end_time.strftime("%Y-%m-%d"),
            "minmagnitude": min_magnitude,
            **PAKISTAN_BOUNDS,
        }
        
        try:
            response = await self.client.get(USGS_EARTHQUAKE_URL, params=params)
            response.raise_for_status()
            data = response.json()
            
            earthquakes = []
            for feature in data.get("features", []):
                props = feature.get("properties", {})
                geom = feature.get("geometry", {})
                coords = geom.get("coordinates", [0, 0, 0])
                
                # USGS returns time in milliseconds
                quake_time_ms = props.get("time", 0)
                quake_time = datetime.fromtimestamp(quake_time_ms / 1000, tz=timezone.utc)
                
                earthquake = Earthquake(
                    id=feature.get("id", "unknown"),
                    magnitude=props.get("mag", 0.0),
                    depth_km=coords[2] if len(coords) > 2 else 0.0,
                    latitude=coords[1] if len(coords) > 1 else 0.0,
                    longitude=coords[0] if len(coords) > 0 else 0.0,
                    location_description=props.get("place", "Unknown location"),
                    quake_time=quake_time,
                )
                earthquakes.append(earthquake)
            
            logger.info(f"Fetched {len(earthquakes)} earthquakes from USGS")
            return earthquakes
            
        except Exception as e:
            logger.error(f"Error fetching earthquakes: {e}")
            raise
    
    def find_nearest_city(self, earthquake: Earthquake) -> Tuple[str, float]:
        """
        Find the nearest monitored city to an earthquake.
        
        Args:
            earthquake: Earthquake object
            
        Returns:
            Tuple of (city_name, distance_km)
        """
        nearest_city = None
        min_distance = float("inf")
        
        for city, (lat, lon) in PAKISTAN_CITIES.items():
            distance = haversine_distance(earthquake.latitude, earthquake.longitude, lat, lon)
            if distance < min_distance:
                min_distance = distance
                nearest_city = city
        
        return nearest_city, min_distance
    
    def analyze_city_risk(
        self, city: str, city_coords: Tuple[float, float], earthquakes: List[Earthquake]
    ) -> CityEarthquakeAlert:
        """
        Analyze earthquake risk for a specific city.
        
        Args:
            city: City name
            city_coords: (latitude, longitude) of the city
            earthquakes: List of recent earthquakes
            
        Returns:
            CityEarthquakeAlert for the city
        """
        city_lat, city_lon = city_coords
        
        # Find nearest/strongest quake within 500km
        nearest_quake = None
        min_distance = float("inf")
        max_magnitude = 0.0
        
        for quake in earthquakes:
            distance = haversine_distance(city_lat, city_lon, quake.latitude, quake.longitude)
            
            # Consider quakes within 500km
            if distance < 500:
                # Prioritize by magnitude, then by distance
                if quake.magnitude > max_magnitude or (
                    quake.magnitude == max_magnitude and distance < min_distance
                ):
                    max_magnitude = quake.magnitude
                    min_distance = distance
                    nearest_quake = quake
        
        # Determine risk level
        if nearest_quake:
            risk_level = calculate_risk_level(nearest_quake.magnitude)
            alert_triggered = risk_level == EarthquakeRiskLevel.HIGH
            recommendation = get_recommendation(risk_level, city, nearest_quake.magnitude)
        else:
            risk_level = EarthquakeRiskLevel.LOW
            alert_triggered = False
            min_distance = 0.0
            recommendation = f"No significant seismic activity detected near {city}."
        
        return CityEarthquakeAlert(
            city=city,
            nearest_quake=nearest_quake,
            distance_km=min_distance,
            risk_level=risk_level,
            alert_triggered=alert_triggered,
            recommendation=recommendation,
        )
    
    async def fetch_and_analyze(self) -> EarthquakeResult:
        """
        Fetch earthquakes and analyze risk for all monitored cities.
        
        Returns:
            EarthquakeResult with alerts for all cities
        """
        timestamp = datetime.now(timezone.utc).isoformat()
        alerts: List[CityEarthquakeAlert] = []
        errors: List[str] = []
        total_quakes = 0
        
        try:
            earthquakes = await self.fetch_earthquakes()
            total_quakes = len(earthquakes)
            
            for city, coords in PAKISTAN_CITIES.items():
                alert = self.analyze_city_risk(city, coords, earthquakes)
                alerts.append(alert)
                
                if alert.alert_triggered:
                    logger.warning(
                        f"EARTHQUAKE ALERT: {city} - M{alert.nearest_quake.magnitude:.1f} "
                        f"at {alert.distance_km:.0f}km"
                    )
                else:
                    logger.info(f"{city}: Earthquake risk={alert.risk_level.value}")
                    
        except Exception as e:
            error_msg = f"Failed to fetch earthquake data: {e}"
            logger.error(error_msg)
            errors.append(error_msg)
        
        return EarthquakeResult(
            timestamp=timestamp,
            total_quakes_found=total_quakes,
            cities_analyzed=len(alerts),
            alerts=alerts,
            errors=errors,
        )


class EarthquakeSenseDataFetcher:
    """Main earthquake data fetcher for DisasterSense."""
    
    async def fetch_and_analyze(self) -> EarthquakeResult:
        """Fetch earthquake data and analyze risk for all cities."""
        async with EarthquakeFetcher() as fetcher:
            return await fetcher.fetch_and_analyze()
