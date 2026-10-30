"""
Middleware qui vérifie que la pharmacie appelante est bien
sur l'instance correspondant à son deployment_env.
"""
import os
from fastapi import Request
from fastapi.responses import JSONResponse

INSTANCE_NAME = os.getenv("INSTANCE_NAME", "basic")

# Routes exclues du contrôle d'instance
EXCLUDED_PREFIXES = ["/auth/", "/health", "/docs", "/openapi", "/redoc", "/platform/"]

async def instance_guard_middleware(request: Request, call_next):
    # Passer les routes publiques
    if any(request.url.path.startswith(p) for p in EXCLUDED_PREFIXES):
        return await call_next(request)

    # Vérifier l'instance via header X-Instance (positionné par Nginx ou client)
    client_instance = request.headers.get("X-Instance", "")
    if client_instance and client_instance != INSTANCE_NAME:
        return JSONResponse(
            status_code=307,
            content={
                "detail": "Wrong instance",
                "expected_instance": INSTANCE_NAME,
                "received_instance": client_instance,
            }
        )

    return await call_next(request)
