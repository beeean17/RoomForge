from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    api_environment: str = "local"
    firebase_project_id: str = "roomforge-dev"
    oracle_dsn: str = "localhost/freepdb1"
    oracle_user: str = "roomforge"
    oracle_password: str = "change-me"
    enable_external_cv_provider: bool = False
    firebase_auth_emulator_host: str = ""
    firebase_admin_credentials_path: str = ""
    source_image_max_bytes: int = 10 * 1024 * 1024
    source_image_allowed_content_types: str = "image/jpeg,image/png,image/webp"
    room_default_height_meters: float = 2.4
    use_in_memory_repositories: bool = False
    cors_allow_origins: str = "http://localhost:9239,http://127.0.0.1:9239,http://localhost:5000,http://127.0.0.1:5000"
    cors_allow_origin_regex: str = r"^http://(localhost|127\.0\.0\.1):\d+$"

    model_config = SettingsConfigDict(env_file=".env", env_prefix="ROOMFORGE_")


settings = Settings()
