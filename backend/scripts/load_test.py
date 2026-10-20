"""Conservative, staging-only API load test runner (standard library only).

The default mode is a dry run and performs no network requests. Real runs require
an explicit staging URL, an exact hostname allow-list, and a CSV of dedicated
test accounts. Production-like hostnames and non-HTTPS targets are rejected.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import csv
import json
import math
import os
import statistics
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


PRODUCTION_HOST_MARKERS = ("onrender.com", "aivencloud.com", "render.com")
DEFAULT_PATHS = ("/stock/medicines?page=1&page_size=10", "/dashboard/stats?days=7")


@dataclass
class RequestResult:
    latency_ms: float
    status_code: Optional[int]
    error: Optional[str] = None


def validate_staging_target(base_url: str, allowed_hosts: str) -> tuple[str, str]:
    parsed = urllib.parse.urlparse(base_url.strip())
    if parsed.scheme != "https":
        raise ValueError("Load tests require an HTTPS staging URL")
    if not parsed.hostname or parsed.username or parsed.password:
        raise ValueError("URL must have a hostname and must not embed credentials")
    host = parsed.hostname.lower().rstrip(".")
    if any(marker in host for marker in PRODUCTION_HOST_MARKERS):
        raise ValueError("Production/provider hostname rejected; use a dedicated staging host")
    allowed = {item.strip().lower().rstrip(".") for item in allowed_hosts.split(",") if item.strip()}
    if not allowed or host not in allowed:
        raise ValueError("Target hostname must exactly match PHARMAGEST_LOADTEST_ALLOWED_HOSTS")
    if parsed.path not in ("", "/") or parsed.query or parsed.fragment:
        raise ValueError("Provide only the staging origin, without path, query, or fragment")
    return f"https://{host}" + (f":{parsed.port}" if parsed.port else ""), host


def load_accounts(csv_path: Path, requested_count: int) -> list[tuple[str, str]]:
    accounts = []
    with csv_path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames or not {"username", "password"}.issubset(reader.fieldnames):
            raise ValueError("Account CSV must contain username,password columns")
        for row in reader:
            username = (row.get("username") or "").strip()
            password = row.get("password") or ""
            if username and password:
                accounts.append((username, password))
    if len(accounts) < requested_count:
        raise ValueError(f"Need {requested_count} dedicated test accounts; CSV contains {len(accounts)}")
    if len({username for username, _ in accounts[:requested_count]}) != requested_count:
        raise ValueError("Each virtual user must have a distinct test account")
    return accounts[:requested_count]


def _request_json(url: str, data: Optional[bytes] = None, token: Optional[str] = None):
    headers = {"Accept": "application/json", "User-Agent": "PharmaGest-Staging-LoadTest/1.0"}
    if data is not None:
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, data=data, headers=headers)
    # Never follow redirects: a staging response must not redirect authenticated
    # load-test traffic to a production host.
    class NoRedirectHandler(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, response_headers, new_url):
            return None

    opener = urllib.request.build_opener(NoRedirectHandler)
    with opener.open(request, timeout=20) as response:
        body = response.read()
        return response.status, json.loads(body.decode("utf-8")) if body else {}


def _login(base_url: str, username: str, password: str) -> str:
    encoded = urllib.parse.urlencode({"username": username, "password": password}).encode()
    status_code, payload = _request_json(base_url + "/auth/login", data=encoded)
    if status_code != 200 or not payload.get("access_token"):
        raise RuntimeError(f"staging login failed (HTTP {status_code})")
    return payload["access_token"]


def _percentile(values: list[float], percentile: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    index = max(0, math.ceil(percentile * len(ordered)) - 1)
    return ordered[index]


def _virtual_user(base_url: str, username: str, password: str, duration: float, stop: threading.Event):
    try:
        token = _login(base_url, username, password)
    except (urllib.error.URLError, TimeoutError, RuntimeError, ValueError) as exc:
        return [RequestResult(0, None, f"login:{type(exc).__name__}")]

    results = []
    endpoint_index = 0
    deadline = time.monotonic() + duration
    while time.monotonic() < deadline and not stop.is_set():
        path = DEFAULT_PATHS[endpoint_index % len(DEFAULT_PATHS)]
        endpoint_index += 1
        started = time.perf_counter()
        try:
            status_code, _ = _request_json(base_url + path, token=token)
            latency = (time.perf_counter() - started) * 1000
            results.append(RequestResult(latency, status_code, None if 200 <= status_code < 400 else "http_error"))
        except urllib.error.HTTPError as exc:
            latency = (time.perf_counter() - started) * 1000
            results.append(RequestResult(latency, exc.code, "http_error"))
        except (urllib.error.URLError, TimeoutError, OSError, ValueError) as exc:
            latency = (time.perf_counter() - started) * 1000
            results.append(RequestResult(latency, None, type(exc).__name__))
        # Model a modest user think-time; do not create a tight request loop.
        stop.wait(1.0)
    return results


def run_load_test(base_url: str, accounts: list[tuple[str, str]], users: int, duration: int):
    started = time.monotonic()
    stop = threading.Event()
    all_results: list[RequestResult] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=users) as executor:
        futures = [executor.submit(_virtual_user, base_url, username, password, duration, stop)
                   for username, password in accounts[:users]]
        try:
            for future in concurrent.futures.as_completed(futures, timeout=duration + 45):
                all_results.extend(future.result())
        except concurrent.futures.TimeoutError:
            stop.set()
            for future in futures:
                future.cancel()
    elapsed = max(time.monotonic() - started, 0.001)
    latencies = [row.latency_ms for row in all_results if row.status_code is not None]
    failures = sum(row.error is not None for row in all_results)
    return {
        "users": users,
        "duration_seconds": duration,
        "elapsed_seconds": round(elapsed, 2),
        "requests": len(all_results),
        "requests_per_second": round(len(all_results) / elapsed, 2),
        "errors": failures,
        "error_rate_percent": round((failures / len(all_results) * 100) if all_results else 100, 2),
        "latency_ms": {
            "average": round(statistics.fmean(latencies), 2) if latencies else None,
            "p50": round(_percentile(latencies, 0.50), 2) if latencies else None,
            "p95": round(_percentile(latencies, 0.95), 2) if latencies else None,
            "p99": round(_percentile(latencies, 0.99), 2) if latencies else None,
        },
        "http_status_counts": {
            str(code): sum(1 for row in all_results if row.status_code == code)
            for code in sorted({row.status_code for row in all_results if row.status_code is not None})
        },
        "login_or_transport_errors": sum(1 for row in all_results if row.status_code is None),
    }


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default=os.getenv("PHARMAGEST_STAGING_URL", ""))
    parser.add_argument("--users", type=int, default=10)
    parser.add_argument("--duration-seconds", type=int, default=60)
    parser.add_argument("--accounts-csv", type=Path, default=None)
    parser.add_argument("--dry-run", action="store_true", help="Validate configuration only; no network calls (default unless --execute is passed).")
    parser.add_argument("--execute", action="store_true", help="Send traffic to the allow-listed staging target.")
    args = parser.parse_args(argv)

    if not 1 <= args.users <= 1000:
        parser.error("--users must be between 1 and 1000")
    if not 1 <= args.duration_seconds <= 3600:
        parser.error("--duration-seconds must be between 1 and 3600")
    if args.execute and args.dry_run:
        parser.error("Choose either --execute or --dry-run, not both")

    allowed_hosts = os.getenv("PHARMAGEST_LOADTEST_ALLOWED_HOSTS", "")
    if not args.base_url or not allowed_hosts:
        parser.error("Set PHARMAGEST_STAGING_URL and PHARMAGEST_LOADTEST_ALLOWED_HOSTS explicitly")
    try:
        normalized_url, hostname = validate_staging_target(args.base_url, allowed_hosts)
        if args.accounts_csv is None:
            raise ValueError("--accounts-csv must point to dedicated staging-only test accounts")
        accounts = load_accounts(args.accounts_csv, args.users)
    except (ValueError, OSError) as exc:
        parser.error(str(exc))

    if not args.execute:
        print(json.dumps({
            "mode": "dry-run",
            "network_requests_sent": 0,
            "staging_host": hostname,
            "users": args.users,
            "duration_seconds": args.duration_seconds,
            "dedicated_accounts_available": len(accounts),
            "planned_endpoints": list(DEFAULT_PATHS),
        }, indent=2))
        return 0

    report = run_load_test(normalized_url, accounts, args.users, args.duration_seconds)
    report["staging_host"] = hostname
    print(json.dumps(report, indent=2))
    return 0 if report["requests"] and report["errors"] == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())