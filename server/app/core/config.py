from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    api_environment: str = "local"
    firebase_project_id: str = "roomforge-dev"
    oracle_dsn: str = "localhost/freepdb1"
    oracle_user: str = "roomforge"
    oracle_password: str = "change-me"
    enable_external_cv_provider: bool = False

    model_config = SettingsConfigDict(env_file=".env", env_prefix="ROOMFORGE_")


settings = Settings()
