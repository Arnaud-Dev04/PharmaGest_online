"""
render_main.py — Point d'entrée Render/Production (Linux).

Ce fichier est utilisé uniquement sur Render.
Il démarre uniquement l'API FastAPI sans le code Desktop Windows.
Start Command Render : uvicorn render_main:app --host 0.0.0.0 --port $PORT
"""

import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.requests import Request
from contextlib import asynccontextmanager
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

# Rate limiter global — partagé avec les routes
limiter = Limiter(key_func=get_remote_address)

# ── Import des routes ─────────────────────────────────────────────────────────
from app.routes.auth import router as auth_router
from app.routes.metrics import router as metrics_router
from app.routes.stock import router as stock_router
from app.routes.config import router as config_router
from app.routes.suppliers import router as suppliers_router
from app.routes.sales import router as sales_router
from app.routes.dashboard import router as dashboard_router
from app.routes.reports import router as reports_router
from app.routes.settings import router as settings_router
from app.routes.admin import router as admin_router
from app.routes.users import router as users_router
from app.routes.customers import router as customers_router
from app.routes.medicine_pricing import router as medicine_pricing_router
from app.routes.pos import router as pos_router

# Routers optionnels (peuvent ne pas exister sur Render selon la version)
try:
    from app.routes.license import router as license_router
    _has_license = True
except ImportError:
    license_router = None
    _has_license = False

try:
    from app.routes.sync import router as sync_router
    _has_sync = True
except ImportError:
    sync_router = None
    _has_sync = False

from app.database import init_local_db


@asynccontextmanager
async def lifespan(application: FastAPI):
    """Initialise la base de données au démarrage."""
    print("[Render] Démarrage PharmaGestion API...")
    try:
        # Toujours init la DB locale (SQLite — même si éphémère, nécessaire pour les sessions)
        from app.database import init_local_db
        init_local_db()
        print("[Render] DB locale (SQLite) initialisée.")
    except Exception as e:
        print(f"[Render][WARNING] SQLite init warning: {e}")

    try:
        # Init la DB remote (MySQL) si configuree
        from app.database import init_remote_db
        import os
        db_remote = os.getenv("DB_URL_REMOTE", "")
        if db_remote and "mysql" in db_remote:
            init_remote_db()
            print("[Render] DB remote (MySQL) initialisee.")
    except Exception as e:
        print(f"[Render][WARNING] Remote DB init warning: {e}")

    try:
        # Sync legacy stock au démarrage (une seule fois, pas à chaque recherche)
        from app.database import SessionLocal
        from app.services.pos_service import sync_legacy_stock
        with SessionLocal() as _db:
            created = sync_legacy_stock(_db)
            if created:
                print(f"[Render] {created} lot(s) auto-créé(s) via sync_legacy_stock.")
    except Exception as e:
        print(f"[Render][WARNING] sync_legacy_stock at startup: {e}")

    print("[Render] API prête ✅")
    yield
    print("[Render] Arrêt du serveur.")



# ── Application FastAPI ───────────────────────────────────────────────────────
app = FastAPI(
    title="PharmaGestion API",
    description="Système de gestion de pharmacie — API REST",
    version="2.0.0",
    lifespan=lifespan,
)

# Rate limiting — protection anti-brute-force
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# ── CORS ──────────────────────────────────────────────────────────────────────
_cors_env = os.environ.get("ALLOWED_ORIGINS", "*").strip()
if _cors_env == "*":
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )
else:
    _allowed = [o.strip() for o in _cors_env.split(",") if o.strip()]
    app.add_middleware(
        CORSMiddleware,
        allow_origins=_allowed,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


# ── Routes ────────────────────────────────────────────────────────────────────
app.include_router(auth_router,             prefix="/auth",     tags=["Auth"])
app.include_router(metrics_router,                              tags=["Metrics"])
app.include_router(stock_router,            prefix="/stock",    tags=["Stock"])
app.include_router(config_router,           prefix="/config",   tags=["Config"])
app.include_router(suppliers_router,        prefix="/suppliers",tags=["Suppliers"])
app.include_router(sales_router,            prefix="/sales",    tags=["Sales"])
app.include_router(dashboard_router,        prefix="/dashboard",tags=["Dashboard"])
app.include_router(reports_router,          prefix="/reports",  tags=["Reports"])
app.include_router(settings_router,         prefix="/settings", tags=["Settings"])
app.include_router(admin_router,            prefix="/admin",    tags=["Admin"])
app.include_router(users_router,            prefix="/users",    tags=["Users"])
app.include_router(customers_router,        prefix="/customers",tags=["Customers"])
app.include_router(medicine_pricing_router, prefix="/pricing",  tags=["Pricing"])
app.include_router(pos_router,              prefix="/pos",      tags=["POS"])
if _has_license and license_router:
    app.include_router(license_router,      prefix="/license",  tags=["License"])
if _has_sync and sync_router:
    app.include_router(sync_router,         prefix="/sync",     tags=["Sync"])


@app.get("/health", tags=["Health"])
async def health_check():
    return {"status": "ok", "service": "PharmaGestion API", "version": "2.0.0"}


@app.get("/", tags=["Health"])
async def root():
    return {"message": "PharmaGestion API — v2.0.0", "docs": "/docs"}
