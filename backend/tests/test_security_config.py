"""Tests for fail-closed production security configuration."""

import pytest

from app.core.cors_config import get_allowed_origins
from app.utils.security import load_secret_key


def test_production_rejects_missing_or_short_jwt_secret():
    for secret in (None, "short-secret"):
        with pytest.raises(RuntimeError, match="SECRET_KEY"):
            load_secret_key(secret, "production")


def test_production_rejects_known_default_jwt_secrets():
    for secret in (
        "pharma-local-s3cur3-k3y-2026-d3fault",
        "pharma-gest-s3cur3-k3y-2026-render",
    ):
        with pytest.raises(RuntimeError, match="known default keys"):
            load_secret_key(secret, "production")


def test_production_accepts_private_secret_of_sufficient_length():
    secret = "private-production-key-with-at-least-32-chars"
    assert load_secret_key(secret, "production") == secret


def test_local_environment_keeps_offline_default_key():
    assert load_secret_key(None, "development") == "pharma-local-s3cur3-k3y-2026-d3fault"


def test_production_cors_requires_explicit_origins():
    for origins in (None, "", "*"):
        with pytest.raises(RuntimeError, match="ALLOWED_ORIGINS|Wildcard"):
            get_allowed_origins(origins, "production")


def test_production_cors_normalizes_explicit_origins():
    assert get_allowed_origins(
        " https://app.example.com/, https://admin.example.com ",
        "production",
    ) == ["https://app.example.com", "https://admin.example.com"]


def test_development_cors_defaults_to_wildcard():
    assert get_allowed_origins(None, "development") == ["*"]