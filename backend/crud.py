"""CRUD operations for DisasterSense database."""

from typing import List, Optional

from sqlalchemy.orm import Session

try:
    from .database import CityAlert, FetchRun, EarthquakeRun, EarthquakeAlert
    from .models import DisasterSenseResult
    from .earthquake_fetcher import EarthquakeResult
except ImportError:
    from database import CityAlert, FetchRun, EarthquakeRun, EarthquakeAlert
    from models import DisasterSenseResult
    from earthquake_fetcher import EarthquakeResult


def save_run(db: Session, result: DisasterSenseResult) -> FetchRun:
    """
    Save a fetch run and all its city alerts to the database.
    
    Args:
        db: Database session
        result: DisasterSenseResult from the fetcher
        
    Returns:
        The created FetchRun record
    """
    # Create the run record
    run = FetchRun(
        cities_analyzed=result.cities_analyzed,
        had_errors=len(result.errors) > 0,
    )
    db.add(run)
    db.flush()  # Get the run.id
    
    # Create alert records for each city
    for alert in result.alerts:
        city_alert = CityAlert(
            run_id=run.id,
            city=alert.city,
            risk_level=alert.risk_level.value,
            rainfall_3day_mm=alert.cumulative_rainfall_3day,
            alert_triggered=alert.alert_triggered,
            forecast_summary=alert.forecast_summary,
            recommendation=alert.recommendation,
        )
        db.add(city_alert)
    
    db.commit()
    db.refresh(run)
    return run


def get_history(db: Session, limit: int = 10) -> List[FetchRun]:
    """
    Get the last N fetch runs with their alerts.
    
    Args:
        db: Database session
        limit: Maximum number of runs to return
        
    Returns:
        List of FetchRun records (most recent first)
    """
    return (
        db.query(FetchRun)
        .order_by(FetchRun.timestamp.desc())
        .limit(limit)
        .all()
    )


def get_city_history(db: Session, city: str, limit: int = 10) -> List[CityAlert]:
    """
    Get the last N alerts for a specific city.
    
    Args:
        db: Database session
        city: City name (case-insensitive)
        limit: Maximum number of alerts to return
        
    Returns:
        List of CityAlert records (most recent first)
    """
    return (
        db.query(CityAlert)
        .join(FetchRun)
        .filter(CityAlert.city.ilike(city))
        .order_by(FetchRun.timestamp.desc())
        .limit(limit)
        .all()
    )


def get_run_by_id(db: Session, run_id: int) -> Optional[FetchRun]:
    """
    Get a specific fetch run by ID.
    
    Args:
        db: Database session
        run_id: The run ID
        
    Returns:
        FetchRun record or None
    """
    return db.query(FetchRun).filter(FetchRun.id == run_id).first()


def get_alerts_by_run(db: Session, run_id: int) -> List[CityAlert]:
    """
    Get all alerts for a specific run.
    
    Args:
        db: Database session
        run_id: The run ID
        
    Returns:
        List of CityAlert records
    """
    return db.query(CityAlert).filter(CityAlert.run_id == run_id).all()


# ─── Earthquake CRUD Operations ────────────────────────────────────────────────

def save_earthquake_run(db: Session, result: EarthquakeResult) -> EarthquakeRun:
    """
    Save an earthquake fetch run and all its city alerts to the database.
    
    Args:
        db: Database session
        result: EarthquakeResult from the fetcher
        
    Returns:
        The created EarthquakeRun record
    """
    run = EarthquakeRun(
        total_quakes_found=result.total_quakes_found,
        cities_analyzed=result.cities_analyzed,
        had_errors=len(result.errors) > 0,
    )
    db.add(run)
    db.flush()
    
    for alert in result.alerts:
        eq_alert = EarthquakeAlert(
            run_id=run.id,
            city=alert.city,
            magnitude=alert.nearest_quake.magnitude if alert.nearest_quake else None,
            depth_km=alert.nearest_quake.depth_km if alert.nearest_quake else None,
            risk_level=alert.risk_level.value,
            location_description=alert.nearest_quake.location_description if alert.nearest_quake else None,
            quake_time=alert.nearest_quake.quake_time if alert.nearest_quake else None,
            distance_km=alert.distance_km if alert.nearest_quake else None,
            alert_triggered=alert.alert_triggered,
            recommendation=alert.recommendation,
        )
        db.add(eq_alert)
    
    db.commit()
    db.refresh(run)
    return run


def get_earthquake_history(db: Session, limit: int = 10) -> List[EarthquakeRun]:
    """
    Get the last N earthquake fetch runs with their alerts.
    
    Args:
        db: Database session
        limit: Maximum number of runs to return
        
    Returns:
        List of EarthquakeRun records (most recent first)
    """
    return (
        db.query(EarthquakeRun)
        .order_by(EarthquakeRun.timestamp.desc())
        .limit(limit)
        .all()
    )


def get_earthquake_city_history(db: Session, city: str, limit: int = 10) -> List[EarthquakeAlert]:
    """
    Get the last N earthquake alerts for a specific city.
    
    Args:
        db: Database session
        city: City name (case-insensitive)
        limit: Maximum number of alerts to return
        
    Returns:
        List of EarthquakeAlert records (most recent first)
    """
    return (
        db.query(EarthquakeAlert)
        .join(EarthquakeRun)
        .filter(EarthquakeAlert.city.ilike(city))
        .order_by(EarthquakeRun.timestamp.desc())
        .limit(limit)
        .all()
    )
