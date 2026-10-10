import json
from typing import Annotated, Optional

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    database_url: str = "postgresql+psycopg://kamusi:kamusi@localhost:5432/kamusi"
    api_key: str = "dev-api-key"
    admin_api_key: Optional[str] = Field(default=None, alias="ADMIN_API_KEY")
    openai_api_key: Optional[str] = Field(default=None, alias="OPENAI_API_KEY")

    # Signing key for admin session tokens. Rotating it invalidates every
    # session. The default is for local development only; startup refuses to
    # serve with it once the app is not in debug mode.
    session_secret: str = "dev-session-secret-change-me"
    session_max_age_seconds: int = 60 * 60 * 12

    # Trigram similarity floor for the "did you mean" pass in /search.
    # 0.3 is the pg_trgm default: lower widens the net, higher demands a
    # closer spelling. Postgres only; ignored on other backends.
    search_fuzzy_threshold: float = 0.3

    # NoDecode stops pydantic-settings from JSON-decoding the env value before
    # validation. Without it, CORS_ORIGINS="http://localhost:3000" raises a
    # SettingsError at import time and the app never starts, because the
    # validator below never gets to see the raw string.
    cors_origins: Annotated[list[str], NoDecode] = Field(
        default_factory=lambda: ["http://localhost:3000"], alias="CORS_ORIGINS"
    )

    @field_validator("cors_origins", mode="before")
    @classmethod
    def parse_cors_origins(cls, value: object) -> list[str]:
        """Accept a JSON array, a comma-separated list, or a single origin."""
        if value is None:
            return []
        if isinstance(value, list):
            return [str(item).strip() for item in value if str(item).strip()]
        if isinstance(value, str):
            raw = value.strip()
            if not raw:
                return []
            if raw.startswith("["):
                try:
                    parsed = json.loads(raw)
                except json.JSONDecodeError:
                    parsed = None
                if isinstance(parsed, list):
                    return [str(item).strip() for item in parsed if str(item).strip()]
            return [item.strip() for item in raw.split(",") if item.strip()]
        return [str(value).strip()]


settings = Settings()


def warn_on_insecure_defaults() -> list[str]:
    """Settings that are fine locally but must not reach a deployment."""
    problems = []
    if settings.session_secret == "dev-session-secret-change-me":
        problems.append(
            "SESSION_SECRET is the built-in development value. Set it to a long "
            "random string; anyone who knows it can mint admin sessions."
        )
    if (settings.admin_api_key or settings.api_key) == "dev-api-key":
        problems.append(
            "ADMIN_API_KEY is the built-in development value. Set it to a secret."
        )
    return problems
