"""Safety and metrics tests for the staging load-test harness."""

import importlib.util
from pathlib import Path
import sys

import pytest


SCRIPT_PATH = Path(__file__).parents[1] / "scripts" / "load_test.py"
SPEC = importlib.util.spec_from_file_location("pharmagest_load_test", SCRIPT_PATH)
load_test = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = load_test
SPEC.loader.exec_module(load_test)


def test_target_requires_exact_allowlisted_https_staging_host():
    url, host = load_test.validate_staging_target(
        "https://staging.pharmagest.example",
        "staging.pharmagest.example",
    )
    assert url == "https://staging.pharmagest.example"
    assert host == "staging.pharmagest.example"


@pytest.mark.parametrize(
    "url,allowlist",
    [
        ("http://staging.pharmagest.example", "staging.pharmagest.example"),
        ("https://staging.pharmagest.example", "other.pharmagest.example"),
        ("https://pharmagest-pnn8.onrender.com", "pharmagest-pnn8.onrender.com"),
        ("https://mydb.aivencloud.com", "mydb.aivencloud.com"),
        ("https://user:pass@staging.pharmagest.example", "staging.pharmagest.example"),
    ],
)
def test_target_rejects_non_staging_or_unsafe_url(url, allowlist):
    with pytest.raises(ValueError):
        load_test.validate_staging_target(url, allowlist)


def test_percentile_uses_nearest_rank():
    assert load_test._percentile([10, 20, 30, 40, 50], 0.95) == 50
    assert load_test._percentile([], 0.95) == 0


def test_http_client_does_not_follow_redirects(monkeypatch):
    class FakeResponse:
        status = 302

        def __enter__(self):
            return self

        def __exit__(self, *_args):
            return False

        def read(self):
            return b"{}"

    captured = {}

    class FakeOpener:
        def open(self, request, timeout):
            captured["url"] = request.full_url
            captured["timeout"] = timeout
            return FakeResponse()

    class FakeBuilder:
        def __init__(self, handler):
            captured["handler"] = handler

        def open(self, request, timeout):
            return FakeOpener().open(request, timeout)

    monkeypatch.setattr(load_test.urllib.request, "build_opener", FakeBuilder)
    status, _ = load_test._request_json("https://staging.pharmagest.example/health")
    assert status == 302
    assert captured["url"] == "https://staging.pharmagest.example/health"
    assert captured["handler"]().redirect_request(
        None, None, 302, "Found", {}, "https://prod.example"
    ) is None


def test_load_accounts_requires_unique_dedicated_accounts(tmp_path):
    account_file = tmp_path / "accounts.csv"
    account_file.write_text(
        "username,password\nload_a,secret_a\nload_b,secret_b\n",
        encoding="utf-8",
    )
    assert load_test.load_accounts(account_file, 2) == [
        ("load_a", "secret_a"),
        ("load_b", "secret_b"),
    ]

    duplicate_file = tmp_path / "duplicates.csv"
    duplicate_file.write_text(
        "username,password\nload_a,secret_a\nload_a,secret_b\n",
        encoding="utf-8",
    )
    with pytest.raises(ValueError, match="distinct"):
        load_test.load_accounts(duplicate_file, 2)


def test_default_cli_is_dry_run_and_sends_no_requests(monkeypatch, tmp_path, capsys):
    account_file = tmp_path / "accounts.csv"
    account_file.write_text("username,password\nload_a,secret_a\n", encoding="utf-8")
    monkeypatch.setenv("PHARMAGEST_STAGING_URL", "https://staging.pharmagest.example")
    monkeypatch.setenv("PHARMAGEST_LOADTEST_ALLOWED_HOSTS", "staging.pharmagest.example")
    monkeypatch.setattr(load_test, "_request_json", lambda *args, **kwargs: pytest.fail("network call in dry-run"))

    assert load_test.main([
        "--users", "1", "--duration-seconds", "5", "--accounts-csv", str(account_file),
    ]) == 0
    assert '"network_requests_sent": 0' in capsys.readouterr().out