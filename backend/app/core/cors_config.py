"""CORS settings validation shared by the production and desktop entry points."""


def get_allowed_origins(value: str | None, environment: str) -> list[str]:
    """Return normalized origins and fail closed for unsafe production settings."""
    configured = (value or "").strip()
    is_production = environment.strip().lower() in {"prod", "production"}

    if not configured:
        if is_production:
            raise RuntimeError("ALLOWED_ORIGINS must explicitly list frontend origins in production")
        return ["*"]

    origins = [origin.strip().rstrip("/") for origin in configured.split(",") if origin.strip()]
    if not origins:
        raise RuntimeError("ALLOWED_ORIGINS must contain at least one valid origin")
    if any("*" in origin for origin in origins):
        if is_production:
            raise RuntimeError("Wildcard CORS origins are forbidden in production")
        if origins != ["*"]:
            raise RuntimeError("Wildcard CORS cannot be combined with explicit origins")

    return origins