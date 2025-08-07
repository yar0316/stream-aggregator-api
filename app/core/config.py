"""Application configuration settings."""

import os
from typing import List
from pydantic import field_validator
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings."""
    
    # Application settings
    APP_NAME: str = "Stream Aggregator API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    
    # Server settings
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    
    # CORS settings
    ALLOWED_ORIGINS: List[str] = ["*"]
    
    # Database settings (Supabase)
    SUPABASE_URL: str = ""
    SUPABASE_ANON_KEY: str = ""
    SUPABASE_SERVICE_ROLE_KEY: str = ""
    SUPABASE_JWT_SECRET: str = ""
    
    # PostgreSQL Direct Connection (optional)
    POSTGRES_URL: str = ""
    POSTGRES_URL_NON_POOLING: str = ""
    
    # OAuth settings are managed via database (system_settings table)
    
    # API settings
    API_V1_STR: str = "/api"
    
    # Security settings
    SECRET_KEY: str = ""
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days
    
    @field_validator("ALLOWED_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: str | List[str]) -> List[str]:
        """Parse CORS origins."""
        if isinstance(v, str) and not v.startswith("["):
            return [i.strip() for i in v.split(",")]
        elif isinstance(v, (list, str)):
            return v
        raise ValueError(v)
    
    class Config:
        """Pydantic config."""
        env_file = ".env"
        case_sensitive = True


# Global settings instance
_settings: Settings | None = None


def get_settings() -> Settings:
    """Get application settings singleton."""
    global _settings
    if _settings is None:
        _settings = Settings()
    return _settings