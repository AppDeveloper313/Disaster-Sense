"""FastAPI backend for DisasterSense."""

import asyncio
from datetime import datetime, timezone
from typing import Optional
import logging

from fastapi import FastAPI, HTTPException, Query, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from .config import PAKISTAN_CITIES
from .data_fetcher import DisasterSenseDataFetcher
from .earthquake_fetcher import EarthquakeSenseDataFetcher, EarthquakeRiskLevel
from .heatwave_fetcher import HeatwaveDataFetcher
from .models import RiskLevel
from .database import init_db, get_db
from . import crud
from .advisor.chat_handler import WeatherRiskChatHandler

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="DisasterSense API",
    description="Disaster prediction and early warning system for Pakistan",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize fetchers
fetcher = DisasterSenseDataFetcher()
earthquake_fetcher = EarthquakeSenseDataFetcher()
heatwave_fetcher = HeatwaveDataFetcher()

# Initialize multilingual chat advisor
try:
    chat_handler = WeatherRiskChatHandler()
    logger.info("✅ Multilingual Weather Risk Advisor initialized")
except Exception as e:
    chat_handler = None
    logger.warning(f"⚠️  Chat advisor unavailable: {e}")

VALID_CITIES = [name.lower() for name in PAKISTAN_CITIES.keys()]


@app.on_event("startup")
def on_startup():
    """Initialize database tables on startup."""
    logger.info("Initializing database...")
    init_db()
    logger.info("Database initialized.")


# ─── Routes ────────────────────────────────────────────────────────────────────

@app.get("/")
def root():
    """Service info."""
    return {
        "service": "DisasterSense API",
        "status": "running",
        "version": "1.0.0",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "endpoints": {
            "health": "/health",
            "chat": "/api/chat",
            "flood_risk": "/api/flood-risk",
            "flood_alerts_only": "/api/flood-risk/alerts-only",
            "earthquake_risk": "/api/earthquake-risk",
            "earthquake_alerts_only": "/api/earthquake-risk/alerts-only",
            "cities": "/api/cities",
            "history": "/api/history",
            "docs": "/docs",
        },
    }


@app.get("/health")
def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "service": "disaster-sense",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


# ─── Chat Advisor Endpoint ─────────────────────────────────────────────────────

class ChatRequest(BaseModel):
    """Request body for the chat endpoint."""
    message: str = Field(..., min_length=1, max_length=2000, description="User message (English, Roman Urdu, or Urdu)")
    city: Optional[str] = Field(default=None, description="Optional city hint")


@app.post("/api/chat")
async def chat_advisor(request: ChatRequest):
    """
    Multilingual Weather Risk Advisor.

    Accepts messages in English, Roman Urdu, or Pure Urdu.
    Detects language automatically and responds in the same language.

    Uses a 3-tier resilient LLM backend:
      - Tier 1: Google Gemini
      - Tier 2: Groq (Llama 3-70b)
      - Tier 3: OpenRouter

    Enriches responses with contextual risk data from the Location Sensitivity Matrix.
    """
    if not chat_handler:
        raise HTTPException(
            status_code=503,
            detail="Chat advisor is unavailable. Check API key configuration.",
        )

    try:
        result = await chat_handler.handle_message(
            user_message=request.message,
            city_hint=request.city,
        )
        return result.to_dict()
    except Exception as e:
        logger.error(f"Chat error: {e}")
        raise HTTPException(status_code=500, detail=f"Chat processing failed: {str(e)}")


@app.get("/api/flood-risk")
async def get_flood_risk(
    city: Optional[str] = Query(
        default=None,
        description="Filter by city name (karachi, lahore, peshawar, quetta, sukkur)"
    ),
    db: Session = Depends(get_db),
):
    """
    Get flood risk assessment for all cities or a specific city.
    
    - **city**: Optional city name filter (e.g., Karachi, Lahore)
    """
    try:
        result = await fetcher.fetch_and_analyze()
        
        # Save to database
        try:
            crud.save_run(db, result)
            logger.info(f"Saved fetch run to database: {result.cities_analyzed} cities")
        except Exception as db_error:
            logger.error(f"Failed to save to database: {db_error}")

        if city:
            city_lower = city.lower()
            if city_lower not in VALID_CITIES:
                raise HTTPException(
                    status_code=400,
                    detail=f"Unknown city '{city}'. Valid options: {', '.join(VALID_CITIES)}"
                )
            filtered_alerts = [
                alert for alert in result.alerts
                if alert.city.lower() == city_lower
            ]
            if not filtered_alerts:
                raise HTTPException(status_code=404, detail=f"No data found for {city}")
            return {
                "timestamp": result.timestamp,
                "cities_analyzed": 1,
                "alerts": [alert.to_dict() for alert in filtered_alerts],
                "errors": result.errors,
            }

        return result.to_dict()

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching flood risk: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch disaster data")


@app.get("/api/flood-risk/alerts-only")
async def get_active_alerts(db: Session = Depends(get_db)):
    """
    Get only medium and high risk cities.
    
    Returns cities where flood risk is elevated (>30mm rainfall in 3 days).
    """
    try:
        result = await fetcher.fetch_and_analyze()
        
        # Save to database
        try:
            crud.save_run(db, result)
        except Exception as db_error:
            logger.error(f"Failed to save to database: {db_error}")
        
        elevated_alerts = [
            alert for alert in result.alerts
            if alert.risk_level in (RiskLevel.MEDIUM, RiskLevel.HIGH)
        ]
        
        return {
            "timestamp": result.timestamp,
            "total_cities_checked": result.cities_analyzed,
            "elevated_risk_count": len(elevated_alerts),
            "alerts": [alert.to_dict() for alert in elevated_alerts],
            "errors": result.errors,
        }
    except Exception as e:
        logger.error(f"Error fetching active alerts: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch alerts")


@app.get("/api/cities")
def list_cities():
    """List all monitored cities with coordinates."""
    cities = [
        {
            "name": name,
            "latitude": coords[0],
            "longitude": coords[1],
        }
        for name, coords in PAKISTAN_CITIES.items()
    ]
    return {
        "count": len(cities),
        "cities": cities,
    }


# ─── History Endpoints ─────────────────────────────────────────────────────────

@app.get("/api/history")
def get_history(
    limit: int = Query(default=10, ge=1, le=100, description="Number of runs to return"),
    db: Session = Depends(get_db),
):
    """
    Get the last N fetch runs with their alerts.
    
    - **limit**: Number of runs to return (default: 10, max: 100)
    """
    try:
        runs = crud.get_history(db, limit=limit)
        return {
            "count": len(runs),
            "runs": [
                {
                    **run.to_dict(),
                    "alerts": [alert.to_dict() for alert in run.alerts],
                }
                for run in runs
            ],
        }
    except Exception as e:
        logger.error(f"Error fetching history: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch history")


@app.get("/api/history/{city}")
def get_city_history(
    city: str,
    limit: int = Query(default=10, ge=1, le=100, description="Number of results to return"),
    db: Session = Depends(get_db),
):
    """
    Get the last N results for a specific city.
    
    - **city**: City name (karachi, lahore, peshawar, quetta, sukkur)
    - **limit**: Number of results to return (default: 10, max: 100)
    """
    city_lower = city.lower()
    if city_lower not in VALID_CITIES:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown city '{city}'. Valid options: {', '.join(VALID_CITIES)}"
        )
    
    try:
        alerts = crud.get_city_history(db, city=city, limit=limit)
        return {
            "city": city.title(),
            "count": len(alerts),
            "history": [alert.to_dict() for alert in alerts],
        }
    except Exception as e:
        logger.error(f"Error fetching city history: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch city history")


# ─── Earthquake Endpoints ──────────────────────────────────────────────────────

@app.get("/api/earthquake-risk")
async def get_earthquake_risk(
    city: Optional[str] = Query(
        default=None,
        description="Filter by city name (karachi, lahore, peshawar, quetta, sukkur)"
    ),
    db: Session = Depends(get_db),
):
    """
    Get earthquake risk assessment for all cities or a specific city.
    
    Fetches earthquakes from USGS (last 7 days, M4.0+) in Pakistan region
    and maps them to the nearest monitored city.
    
    - **city**: Optional city name filter
    """
    try:
        result = await earthquake_fetcher.fetch_and_analyze()
        
        # Save to database
        try:
            crud.save_earthquake_run(db, result)
            logger.info(f"Saved earthquake run: {result.total_quakes_found} quakes found")
        except Exception as db_error:
            logger.error(f"Failed to save earthquake data: {db_error}")
        
        if city:
            city_lower = city.lower()
            if city_lower not in VALID_CITIES:
                raise HTTPException(
                    status_code=400,
                    detail=f"Unknown city '{city}'. Valid options: {', '.join(VALID_CITIES)}"
                )
            filtered_alerts = [
                alert for alert in result.alerts
                if alert.city.lower() == city_lower
            ]
            if not filtered_alerts:
                raise HTTPException(status_code=404, detail=f"No data found for {city}")
            return {
                "timestamp": result.timestamp,
                "total_quakes_found": result.total_quakes_found,
                "cities_analyzed": 1,
                "alerts": [alert.to_dict() for alert in filtered_alerts],
                "errors": result.errors,
            }
        
        return result.to_dict()
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching earthquake risk: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch earthquake data")


@app.get("/api/earthquake-risk/alerts-only")
async def get_earthquake_alerts_only(db: Session = Depends(get_db)):
    """
    Get only medium and high earthquake risk cities.
    
    Returns cities where earthquake risk is elevated (M4.5+ within 500km).
    """
    try:
        result = await earthquake_fetcher.fetch_and_analyze()
        
        # Save to database
        try:
            crud.save_earthquake_run(db, result)
        except Exception as db_error:
            logger.error(f"Failed to save earthquake data: {db_error}")
        
        elevated_alerts = [
            alert for alert in result.alerts
            if alert.risk_level in (EarthquakeRiskLevel.MEDIUM, EarthquakeRiskLevel.HIGH)
        ]
        
        return {
            "timestamp": result.timestamp,
            "total_quakes_found": result.total_quakes_found,
            "total_cities_checked": result.cities_analyzed,
            "elevated_risk_count": len(elevated_alerts),
            "alerts": [alert.to_dict() for alert in elevated_alerts],
            "errors": result.errors,
        }
    except Exception as e:
        logger.error(f"Error fetching earthquake alerts: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch earthquake alerts")


@app.get("/api/heatwave-risk")
async def get_heatwave_risk(
    city: Optional[str] = Query(default=None, description="Filter by city name"),
):
    """Get heatwave risk assessment."""
    try:
        result = await heatwave_fetcher.fetch_and_analyze()
        if city:
            city_lower = city.lower()
            filtered_alerts = [a for a in result.alerts if a.city.lower() == city_lower]
            if not filtered_alerts:
                raise HTTPException(status_code=404, detail=f"No data found for {city}")
            return {
                "timestamp": result.timestamp,
                "cities_analyzed": 1,
                "alerts": [a.to_dict() for a in filtered_alerts],
                "errors": result.errors,
            }
        return result.to_dict()
    except Exception as e:
        logger.error(f"Error fetching heatwave risk: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch heatwave data")

@app.get("/api/weather/{city}")
async def get_city_weather(city: str):
    """
    Get current weather metrics for a city.

    Returns temperature, humidity, wind speed, weather code, and air quality (PM2.5, AQI).
    Uses Open-Meteo current-weather and air-quality APIs (no API key required).
    """
    import httpx

    city_lower = city.lower()
    if city_lower not in VALID_CITIES:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown city '{city}'. Valid options: {', '.join(VALID_CITIES)}"
        )

    coords = PAKISTAN_CITIES.get(city.title())
    if not coords:
        raise HTTPException(status_code=404, detail=f"Coordinates not found for {city}")

    lat, lon = coords

    weather_url = "https://api.open-meteo.com/v1/forecast"
    aqi_url = "https://air-quality-api.open-meteo.com/v1/air-quality"

    weather_params = {
        "latitude": lat,
        "longitude": lon,
        "current": "temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code,apparent_temperature",
        "daily": "temperature_2m_max,temperature_2m_min,precipitation_sum,weather_code",
        "timezone": "Asia/Karachi",
    }

    aqi_params = {
        "latitude": lat,
        "longitude": lon,
        "current": "pm2_5,us_aqi",
        "timezone": "Asia/Karachi",
    }

    try:
        async with httpx.AsyncClient(timeout=15) as client:
            weather_resp, aqi_resp = await asyncio.gather(
                client.get(weather_url, params=weather_params),
                client.get(aqi_url, params=aqi_params),
            )

        weather_data = weather_resp.json().get("current", {})
        aqi_data = aqi_resp.json().get("current", {})

        weather_code = weather_data.get("weather_code", 0)
        condition, condition_icon = _weather_code_to_condition(weather_code)

        pm25 = aqi_data.get("pm2_5")
        us_aqi = aqi_data.get("us_aqi")
        aqi_category, aqi_color = _aqi_category(us_aqi)

        daily_data = weather_resp.json().get("daily", {})
        forecast = []
        if "time" in daily_data:
            for i in range(len(daily_data["time"])):
                f_code = daily_data["weather_code"][i]
                precip = daily_data["precipitation_sum"][i]
                
                # Open-Meteo sometimes returns Thunderstorm/Rain codes even if precipitation is 0.0mm.
                # Override to Cloudy/Clear if there's no actual rain expected.
                if precip < 0.1 and f_code in [51, 53, 55, 61, 63, 65, 80, 81, 82, 95, 96, 99]:
                    f_code = 2 # Partly Cloudy
                
                f_cond, f_icon = _weather_code_to_condition(f_code)
                forecast.append({
                    "date": daily_data["time"][i],
                    "temp_max_c": daily_data["temperature_2m_max"][i],
                    "temp_min_c": daily_data["temperature_2m_min"][i],
                    "precipitation_mm": precip,
                    "condition": f_cond,
                    "condition_icon": f_icon,
                })

        return {
            "city": city.title(),
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "temperature_c": weather_data.get("temperature_2m"),
            "feels_like_c": weather_data.get("apparent_temperature"),
            "humidity_pct": weather_data.get("relative_humidity_2m"),
            "wind_speed_kmh": weather_data.get("wind_speed_10m"),
            "weather_code": weather_code,
            "condition": condition,
            "condition_icon": condition_icon,
            "air_quality": {
                "pm2_5": round(pm25, 1) if pm25 is not None else None,
                "us_aqi": us_aqi,
                "category": aqi_category,
                "color": aqi_color,
            },
            "forecast": forecast,
        }

    except Exception as e:
        logger.error(f"Error fetching weather for {city}: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch weather data")


def _weather_code_to_condition(code: int) -> tuple[str, str]:
    """Map WMO weather code to a human-readable condition and emoji icon."""
    if code == 0:
        return "Clear Sky", "☀️"
    elif code in (1, 2, 3):
        return "Partly Cloudy", "⛅"
    elif code in (45, 48):
        return "Fog", "🌫️"
    elif code in (51, 53, 55):
        return "Drizzle", "🌦️"
    elif code in (61, 63, 65):
        return "Rain", "🌧️"
    elif code in (71, 73, 75):
        return "Snow", "❄️"
    elif code in (80, 81, 82):
        return "Rain Showers", "🌦️"
    elif code in (95, 96, 99):
        return "Thunderstorm", "⛈️"
    else:
        return "Unknown", "🌡️"


def _aqi_category(aqi: int | None) -> tuple[str, str]:
    """Return AQI category label and hex color."""
    if aqi is None:
        return "Unknown", "#9E9E9E"
    if aqi <= 50:
        return "Good", "#4CAF50"
    elif aqi <= 100:
        return "Moderate", "#FFC107"
    elif aqi <= 150:
        return "Unhealthy for Sensitive Groups", "#FF9800"
    elif aqi <= 200:
        return "Unhealthy", "#F44336"
    elif aqi <= 300:
        return "Very Unhealthy", "#9C27B0"
    else:
        return "Hazardous", "#7B1FA2"


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("backend.main:app", host="0.0.0.0", port=8000, reload=True)