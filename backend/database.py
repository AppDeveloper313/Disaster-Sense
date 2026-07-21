"""Database configuration and SQLAlchemy models for DisasterSense."""

import os
from datetime import datetime, timezone
from urllib.parse import quote_plus

from dotenv import load_dotenv
from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    create_engine,
)
from sqlalchemy.orm import declarative_base, relationship, sessionmaker

# Load environment variables
load_dotenv()

# Database URL setup with SQLite fallback
DATABASE_URL = os.getenv("DATABASE_URL")

<<<<<<< HEAD
if not DATABASE_URL:
    user = os.getenv("DB_USER")
    raw_password = os.getenv("DB_PASSWORD")
    if user and raw_password:
        host = os.getenv("DB_HOST", "localhost")
        port = os.getenv("DB_PORT", "3306")
        db_name = os.getenv("DB_NAME", "disaster_sense")
        safe_password = quote_plus(raw_password)
        DATABASE_URL = f"mysql+pymysql://{user}:{safe_password}@{host}:{port}/{db_name}"
    else:
        DATABASE_URL = "sqlite:///./disaster_sense.db"

# Create engine
if DATABASE_URL.startswith("sqlite"):
    engine = create_engine(DATABASE_URL, echo=False, connect_args={"check_same_thread": False})
else:
=======
# 2. Safety check: make sure we actually found a password
if not raw_password:
    print("Warning: DB_PASSWORD not found! Using fallback SQLite database.")
    DATABASE_URL = "sqlite:///./fallback.db"
    engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
else:
    # 3. Encode the password to handle the '@' and '$$'
    safe_password = quote_plus(raw_password)

    # 4. Construct the URL using 'safe_password'
    DATABASE_URL = f"mysql+pymysql://{user}:{safe_password}@{host}:{port}/{db_name}"
>>>>>>> a22b5114f96f8e209af893576a6ff6e4fd066bea
    engine = create_engine(DATABASE_URL, echo=False, pool_pre_ping=True)

# Session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base class for models
Base = declarative_base()


class FetchRun(Base):
    """Records each time the data fetcher runs."""
    
    __tablename__ = "fetch_runs"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    timestamp = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    cities_analyzed = Column(Integer, nullable=False)
    had_errors = Column(Boolean, default=False, nullable=False)
    
    # Relationship to alerts
    alerts = relationship("CityAlert", back_populates="run", cascade="all, delete-orphan")
    
    def to_dict(self):
        return {
            "id": self.id,
            "timestamp": self.timestamp.isoformat() if self.timestamp else None,
            "cities_analyzed": self.cities_analyzed,
            "had_errors": self.had_errors,
        }


class CityAlert(Base):
    """Flood risk alert for a city during a specific run."""
    
    __tablename__ = "city_alerts"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    run_id = Column(Integer, ForeignKey("fetch_runs.id", ondelete="CASCADE"), nullable=False)
    city = Column(String(100), nullable=False, index=True)
    risk_level = Column(String(20), nullable=False)  # low, medium, high
    rainfall_3day_mm = Column(Float, nullable=False)
    alert_triggered = Column(Boolean, default=False, nullable=False)
    forecast_summary = Column(Text, nullable=True)
    recommendation = Column(Text, nullable=True)
    
    # Relationship to run
    run = relationship("FetchRun", back_populates="alerts")
    
    def to_dict(self):
        return {
            "id": self.id,
            "run_id": self.run_id,
            "city": self.city,
            "risk_level": self.risk_level,
            "rainfall_3day_mm": self.rainfall_3day_mm,
            "alert_triggered": self.alert_triggered,
            "forecast_summary": self.forecast_summary,
            "recommendation": self.recommendation,
            "timestamp": self.run.timestamp.isoformat() if self.run and self.run.timestamp else None,
        }


class EarthquakeRun(Base):
    """Records each time the earthquake fetcher runs."""
    
    __tablename__ = "earthquake_runs"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    timestamp = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    total_quakes_found = Column(Integer, nullable=False, default=0)
    cities_analyzed = Column(Integer, nullable=False)
    had_errors = Column(Boolean, default=False, nullable=False)
    
    # Relationship to alerts
    alerts = relationship("EarthquakeAlert", back_populates="run", cascade="all, delete-orphan")
    
    def to_dict(self):
        return {
            "id": self.id,
            "timestamp": self.timestamp.isoformat() if self.timestamp else None,
            "total_quakes_found": self.total_quakes_found,
            "cities_analyzed": self.cities_analyzed,
            "had_errors": self.had_errors,
        }


class EarthquakeAlert(Base):
    """Earthquake risk alert for a city during a specific run."""
    
    __tablename__ = "earthquake_alerts"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    run_id = Column(Integer, ForeignKey("earthquake_runs.id", ondelete="CASCADE"), nullable=False)
    city = Column(String(100), nullable=False, index=True)
    magnitude = Column(Float, nullable=True)
    depth_km = Column(Float, nullable=True)
    risk_level = Column(String(20), nullable=False)  # low, medium, high
    location_description = Column(Text, nullable=True)
    quake_time = Column(DateTime, nullable=True)
    distance_km = Column(Float, nullable=True)
    alert_triggered = Column(Boolean, default=False, nullable=False)
    recommendation = Column(Text, nullable=True)
    
    # Relationship to run
    run = relationship("EarthquakeRun", back_populates="alerts")
    
    def to_dict(self):
        return {
            "id": self.id,
            "run_id": self.run_id,
            "city": self.city,
            "magnitude": self.magnitude,
            "depth_km": self.depth_km,
            "risk_level": self.risk_level,
            "location_description": self.location_description,
            "quake_time": self.quake_time.isoformat() if self.quake_time else None,
            "distance_km": self.distance_km,
            "alert_triggered": self.alert_triggered,
            "recommendation": self.recommendation,
            "timestamp": self.run.timestamp.isoformat() if self.run and self.run.timestamp else None,
        }


def init_db():
    """Create all tables if they don't exist."""
    Base.metadata.create_all(bind=engine)


def get_db():
    """Dependency for FastAPI to get database session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
