from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field
from typing import Optional


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    database_url: str = "postgresql+psycopg://kamusi:kamusi@localhost:5432/kamusi"
    api_key: str = "dev-api-key"
    admin_api_key: Optional[str] = Field(default=None, alias="ADMIN_API_KEY")
    openai_api_key: Optional[str] = Field(default=None, alias="OPENAI_API_KEY")


settings = Settings()
