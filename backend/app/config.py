from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    mongodb_uri: str = "mongodb://localhost:27017"
    mongodb_db_name: str = "Z-Confecciones"

    jwt_secret: str = "dev-secret-change-in-production-min-32-chars"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 720  # 12 hours

    avatars_dir: str = "static/avatars"
    max_avatar_bytes: int = 2 * 1024 * 1024  # 2 MB

    cors_origins: str = "*"

    @property
    def cors_origin_list(self) -> list[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
