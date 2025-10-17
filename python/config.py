"""Configuration management for PDF AI Notes server."""

from pydantic_settings import BaseSettings, SettingsConfigDict

import os
from dotenv import load_dotenv

load_dotenv()

class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # OpenRouter API Configuration
    openrouter_api_key: str = os.getenv("OPENROUTER_API_KEY")
    openrouter_base_url: str = "https://openrouter.ai/api/v1"

    # Model Configuration
    model_name: str = os.getenv("MODEL_NAME") or "google/gemini-flash-1.5-8b"
    max_tokens: int = 2000
    temperature: float = 0.3  # Lower temperature for more focused summaries

    # Server Configuration
    host: str = "127.0.0.1"
    port: int = 8000
    log_level: str = "info"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )


# Global settings instance
settings = Settings()