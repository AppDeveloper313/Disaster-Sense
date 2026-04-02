"""FastAPI backend for DisasterSense."""

from datetime import datetime, timezone
from typing import Optional
import logging

from fastapi import FastAPI, HTTPException, Query, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from .config import PAKISTAN_CITIES
from .data_fetcher import DisasterSenseDataFetcher
from .earthquake_fetcher import EarthquakeSenseDataFetcher, EarthquakeRiskLevel
from .models import RiskLevel
from .database import init_db, get_db
from . import crud

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

VALID_CITIES = ["karachi", "lahore", "peshawar", "quetta", "sukkur"]


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
            "risk_type": risk_type,
        }
        for name, coords, risk_type in [
            ("Karachi", PAKISTAN_CITIES["Karachi"], "cyclone, heatwave"),
            ("Lahore", PAKISTAN_CITIES["Lahore"], "heatwave, smog"),
            ("Peshawar", PAKISTAN_CITIES["Peshawar"], "flash floods"),
            ("Quetta", PAKISTAN_CITIES["Quetta"], "earthquake"),
            ("Sukkur", PAKISTAN_CITIES["Sukkur"], "monsoon flooding"),
        ]
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


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("backend.main:app", host="0.0.0.0", port=8000, reload=True)