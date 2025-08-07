"""
Stream Aggregator API - Main Application Entry Point

FastAPI-based REST API for aggregating live streams from multiple platforms.
Integrates with Supabase for data persistence and authentication.
"""

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn
import os

from app.core.config import get_settings
from app.core.exceptions import AppException
from app.routers import health

# Get application settings
settings = get_settings()

# Create FastAPI application instance
app = FastAPI(
    title=settings.APP_NAME,
    description="REST API for aggregating live streams from YouTube, Twitch, and other platforms",
    version=settings.APP_VERSION,
    docs_url="/docs",
    redoc_url="/redoc"
)

# Configure CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Global exception handler
@app.exception_handler(AppException)
async def app_exception_handler(request: Request, exc: AppException):
    """Handle custom application exceptions."""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "error": {
                "code": exc.error_code,
                "message": exc.message,
                "details": exc.details
            }
        }
    )


# Include routers
app.include_router(health.router, prefix=settings.API_V1_STR, tags=["health"])


@app.get("/")
async def root():
    """Root endpoint with basic API information."""
    return {
        "message": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "status": "running",
        "docs": "/docs",
        "health": f"{settings.API_V1_STR}/health"
    }


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=settings.HOST,
        port=int(os.getenv("PORT", settings.PORT)),
        reload=settings.DEBUG
    )