"""Health check endpoints."""

from fastapi import APIRouter
from datetime import datetime
import time
from typing import Dict, Any

from app.core.config import get_settings

router = APIRouter()
settings = get_settings()

# Track application start time
_start_time = time.time()


@router.get("/health")
async def health_check() -> Dict[str, Any]:
    """
    System health check endpoint.
    
    Returns application status and basic system information.
    No authentication required.
    """
    current_time = datetime.utcnow()
    uptime_seconds = int(time.time() - _start_time)
    
    return {
        "success": True,
        "data": {
            "status": "healthy",
            "version": settings.APP_VERSION,
            "timestamp": current_time.isoformat() + "Z",
            "uptime_seconds": uptime_seconds,
            "checks": {
                "application": {
                    "status": "up",
                    "last_check_at": current_time.isoformat() + "Z"
                }
            }
        }
    }


@router.get("/health/ready")
async def readiness_check() -> Dict[str, Any]:
    """
    Kubernetes readiness check endpoint.
    
    Returns whether the application is ready to serve traffic.
    """
    return {
        "success": True,
        "data": {
            "status": "ready",
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }
    }


@router.get("/health/live")
async def liveness_check() -> Dict[str, Any]:
    """
    Kubernetes liveness check endpoint.
    
    Returns whether the application is alive and responding.
    """
    return {
        "success": True,
        "data": {
            "status": "alive",
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }
    }