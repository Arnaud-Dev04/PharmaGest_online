"""
Distributed Cache Manager for PharmaGest Multi-Tenant.
Supports:
  - Redis (in cloud multi-worker/production environments)
  - Safe in-memory fallback (when Redis is unavailable or in offline desktop mode)
All keys are automatically scoped with tenant namespaces:
  Format: pharma:{pharmacy_id}:{namespace}:{key}
"""

import os
import json
import time
import logging
from typing import Any, Optional, Dict

logger = logging.getLogger("distributed_cache")

# Redis client setup (optional)
_redis_client = None
_redis_available = False

REDIS_URL = os.getenv("REDIS_URL", "").strip()
if REDIS_URL:
    try:
        import redis
        _redis_client = redis.from_url(
            REDIS_URL,
            decode_responses=True,
            socket_connect_timeout=2,
            socket_timeout=2,
        )
        # Ping to test connectivity
        _redis_client.ping()
        _redis_available = True
        logger.info("[CACHE] Redis distributed cache connected successfully.")
    except Exception as e:
        logger.warning(f"[CACHE] Redis configured at {REDIS_URL} but unreachable: {e}. Falling back to memory.")
        _redis_client = None
        _redis_available = False

# Local in-memory fallback cache
_memory_cache: Dict[str, Dict[str, Any]] = {}
_MAX_MEMORY_ITEMS = 2000


def tenant_key(pharmacy_id: Optional[int], namespace: str, key: str) -> str:
    """Format namespaced tenant cache key: pharma:{pharmacy_id}:{namespace}:{key}."""
    p_id = str(pharmacy_id) if pharmacy_id is not None else "global"
    return f"pharma:{p_id}:{namespace}:{key}"


def get_cache(key: str) -> Optional[Any]:
    """Retrieve value from cache (Redis if available, else memory)."""
    global _memory_cache

    if _redis_available and _redis_client:
        try:
            val = _redis_client.get(key)
            if val is not None:
                try:
                    return json.loads(val)
                except (json.JSONDecodeError, TypeError):
                    return val
            return None
        except Exception as e:
            logger.debug(f"[CACHE] Redis get error: {e}")

    # Fallback memory
    now = time.time()
    entry = _memory_cache.get(key)
    if entry:
        if now < entry["expires_at"]:
            return entry["val"]
        else:
            _memory_cache.pop(key, None)
    return None


def set_cache(key: str, value: Any, ttl_seconds: int = 60) -> None:
    """Store value in cache with TTL (Redis if available, else memory)."""
    global _memory_cache

    if _redis_available and _redis_client:
        try:
            val_str = json.dumps(value) if not isinstance(value, (str, int, float, bool)) else str(value)
            _redis_client.setex(key, ttl_seconds, val_str)
            return
        except Exception as e:
            logger.debug(f"[CACHE] Redis set error: {e}")

    # Fallback memory
    now = time.time()
    if len(_memory_cache) >= _MAX_MEMORY_ITEMS:
        # Evict expired items
        expired = [k for k, v in _memory_cache.items() if now >= v["expires_at"]]
        for k in expired:
            _memory_cache.pop(k, None)
        if len(_memory_cache) >= _MAX_MEMORY_ITEMS:
            # Drop oldest 20%
            sorted_keys = sorted(_memory_cache.keys(), key=lambda k: _memory_cache[k]["expires_at"])
            for k in sorted_keys[:_MAX_MEMORY_ITEMS // 5]:
                _memory_cache.pop(k, None)

    _memory_cache[key] = {
        "val": value,
        "expires_at": now + ttl_seconds,
    }


def delete_cache(key: str) -> None:
    """Delete a single key from cache."""
    global _memory_cache

    if _redis_available and _redis_client:
        try:
            _redis_client.delete(key)
        except Exception as e:
            logger.debug(f"[CACHE] Redis delete error: {e}")

    _memory_cache.pop(key, None)


def invalidate_tenant_namespace(pharmacy_id: Optional[int], namespace: str = "*") -> None:
    """Invalidate all cached keys for a specific pharmacy and namespace."""
    global _memory_cache

    pattern = f"pharma:{pharmacy_id if pharmacy_id is not None else '*'}:{namespace}*"

    if _redis_available and _redis_client:
        try:
            keys = _redis_client.keys(pattern)
            if keys:
                _redis_client.delete(*keys)
        except Exception as e:
            logger.debug(f"[CACHE] Redis keys deletion error: {e}")

    # Memory cache invalidation with proper tenant & namespace matching
    to_delete = []
    ns_target = namespace.strip("*")
    for k in list(_memory_cache.keys()):
        parts = k.split(":")
        # Format: pharma:{pharmacy_id}:{namespace}:{key}
        if len(parts) >= 3 and parts[0] == "pharma":
            k_pharmacy_id = parts[1]
            k_namespace = parts[2]
            pharmacy_matches = (pharmacy_id is None) or (k_pharmacy_id == str(pharmacy_id))
            namespace_matches = (namespace == "*") or (ns_target in k_namespace)
            if pharmacy_matches and namespace_matches:
                to_delete.append(k)

    for k in to_delete:
        _memory_cache.pop(k, None)
