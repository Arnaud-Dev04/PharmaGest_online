"""
FastAPI application entry point.
Main application configuration and startup.
"""

from fastapi import FastAPI, Request, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, JSONResponse
from sqlalchemy.orm import Session
from app.database import init_local_db, get_local_db
from app.core.license import license_service
import uvicorn
import os
import sys
import threading
import socket
import time
import ctypes
from contextlib import asynccontextmanager
import subprocess
import logging

class EndpointLogFilter(logging.Filter):
    """Filtre les pings réguliers de synchronisation (/sync/status) pour garder la console propre."""
    def filter(self, record: logging.LogRecord) -> bool:
        return "/sync/status" not in record.getMessage()

logging.getLogger("uvicorn.access").addFilter(EndpointLogFilter())

# REDIRECT LOGS TO FILE (ONLY IN FROZEN MODE)
if getattr(sys, "frozen", False):
    try:
        log_dir = os.path.join(os.environ.get('APPDATA', '.'), 'PharmaGestion')
        os.makedirs(log_dir, exist_ok=True)
        log_file = open(os.path.join(log_dir, 'backend.log'), 'a')
        sys.stdout = log_file
        sys.stderr = log_file
    except Exception:
        pass

# =========================
# LIFESPAN EVENT HANDLER
# =========================

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Filtrer /sync/status des logs d'accès console Uvicorn
    logging.getLogger("uvicorn.access").addFilter(EndpointLogFilter())

    # Startup — initialisation synchrone de la base pour garantir la disponibilité immédiate
    print("[*] Starting Pharmacy Management System...")
    print("[*] Initializing local database...")
    try:
        init_local_db()
        print("[OK] Local database initialized successfully!")
        print("[OK] Application started successfully!")
    except Exception as e:
        print(f"[ERROR] Error during startup: {e}")
    yield
    # Shutdown
    print("[*] Shutting down...")

# =========================
# CREATE FASTAPI APP
# =========================

app = FastAPI(
    title="Pharmacy Management System",
    description="Backend API for pharmacy management with offline/online sync support",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

# Maintenance marker file path (project root)
MAINT_FILE = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'MAINTENANCE_MODE'))


@app.middleware("http")
async def maintenance_middleware(request: Request, call_next):
    try:
        if os.path.exists(MAINT_FILE):
            path = request.url.path
            # Allow safe endpoints during maintenance
            allowed_prefixes = [
                '/health',
                '/auth',
                '/admin/maintenance',
                '/docs',
                '/redoc',
                '/openapi.json',
                '/assets',
            ]
            if any(path.startswith(p) for p in allowed_prefixes):
                return await call_next(request)

            # Allow read-only requests (GET/HEAD)
            if request.method in ("GET", "HEAD"):
                return await call_next(request)

            # Block mutating requests
            return JSONResponse({'detail': 'Service unavailable - maintenance in progress'}, status_code=503)
    except Exception:
        # On any error, don't block requests
        return await call_next(request)
    # If maintenance file not present, continue as normal
    return await call_next(request)


@app.middleware("http")
async def timing_middleware(request: Request, call_next):
    """Affiche la durée de chaque requête — aide à identifier les endpoints lents."""
    if request.method == "OPTIONS":
        return await call_next(request)
    import time as _t
    t0 = _t.perf_counter()
    response = await call_next(request)
    elapsed = (_t.perf_counter() - t0) * 1000
    path = request.url.path
    qs = f"?{request.url.query}" if request.url.query else ""
    if elapsed > 200:   # Afficher uniquement les requêtes > 200ms
        flag = "🔴 SLOW" if elapsed > 2000 else ("🟡" if elapsed > 800 else "🟢")
        print(f"[TIMING] {flag} {request.method} {path}{qs}  →  {elapsed:.0f}ms", flush=True)
    return response


# =========================
# CORS
# =========================

# ALLOWED_ORIGINS peut etre "*" (dev) ou une liste URLs separees par virgule
_cors_env = os.environ.get("ALLOWED_ORIGINS", "*").strip()
if _cors_env == "*":
    # Dev : autorise toutes les origines (Flutter Web ports aleatoires)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,   # incompatible avec allow_origins=["*"]
        allow_methods=["*"],
        allow_headers=["*"],
    )
else:
    # Production : origines explicites
    _allowed = [o.strip() for o in _cors_env.split(",") if o.strip()]
    app.add_middleware(
        CORSMiddleware,
        allow_origins=_allowed,
        allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )




# =========================
# HEALTH CHECK
# =========================
# Note: La vérification de licence est gérée dans dependencies.py
# pour permettre l'accès Super Admin et utiliser la session DB.

@app.get("/health", tags=["System"])
async def health_check():
    return {"status": "ok"}


# =========================
# GLOBAL EXCEPTION HANDLER
# =========================

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    import traceback
    err_str = traceback.format_exc()
    print(f"[FATAL ERROR on {request.method} {request.url.path}]: {err_str}", flush=True)
    return JSONResponse(
        status_code=500,
        content={"detail": f"Erreur serveur interne: {str(exc)}"}
    )


# =========================
# ROUTES
# =========================

from app.routes import (
    auth_router,
    metrics_router,
    stock_router,
    config_router,
    suppliers_router,
    sales_router,
    dashboard_router,
    reports_router,
    settings_router,
    admin_router,
    maintenance_router,
    users_router,
    customers_router,
    license_router,
    medicine_pricing_router,
    pos_router,
    sync_router,
)

app.include_router(auth_router, prefix="/auth", tags=["Authentication"])
app.include_router(metrics_router, tags=["Metrics"])
app.include_router(stock_router, prefix="/stock", tags=["Stock"])
app.include_router(config_router, prefix="/config", tags=["Configuration"])
app.include_router(suppliers_router, prefix="/suppliers", tags=["Suppliers"])
app.include_router(sales_router, prefix="/sales", tags=["Sales"])
app.include_router(dashboard_router, prefix="/dashboard", tags=["Dashboard"])
app.include_router(reports_router, prefix="/reports", tags=["Reports"])
app.include_router(settings_router, prefix="/settings", tags=["Settings"])
app.include_router(admin_router, prefix="/admin", tags=["Admin"])
app.include_router(maintenance_router, prefix="/admin", tags=["Admin"])
app.include_router(users_router, prefix="/users", tags=["Users"])
app.include_router(customers_router, prefix="/customers", tags=["Customers"])
app.include_router(license_router, prefix="/license", tags=["License"])
app.include_router(medicine_pricing_router, prefix="/pricing", tags=["Pricing"])
app.include_router(pos_router, prefix="/pos", tags=["POS"])
app.include_router(sync_router, prefix="/sync", tags=["Sync"])


# =========================
# SERVE REACT FRONTEND
# =========================

if getattr(sys, "frozen", False):
    # En mode frozen (PyInstaller)
    ELECTRON_MODE_CHECK = os.environ.get("PHARMA_ELECTRON_MODE", "false").lower() == "true"
    
    if ELECTRON_MODE_CHECK:
        # Vérifier si on est vraiment en mode production Electron
        # En production : sys.executable est dans resources/backend/
        # En dev : sys.executable est dans backend/dist/
        exe_dir = os.path.dirname(sys.executable)
        
        # Vérifier si le dossier parent s'appelle "resources" (production) ou autre (dev)
        parent_dir = os.path.dirname(exe_dir)
        parent_name = os.path.basename(parent_dir)
        
        print(f"[DEBUG] sys.executable: {sys.executable}")
        print(f"[DEBUG] exe_dir: {exe_dir}")
        print(f"[DEBUG] parent_dir: {parent_dir}")
        print(f"[DEBUG] parent_name: {parent_name}")
        
        if parent_name == "resources":
            # MODE PRODUCTION ELECTRON
            # Structure : resources/backend/PharmaBackend.exe
            # Frontend dans : resources/frontend/
            resources_dir = parent_dir
            frontend_dist = os.path.join(resources_dir, "frontend")
            print(f"[*] Mode: PRODUCTION ELECTRON")
            print(f"[DEBUG] frontend_dist (resources/frontend): {frontend_dist}")
        else:
            # MODE DÉVELOPPEMENT (backend frozen mais lancé depuis le projet)
            # Structure : C:/projet/backend/dist/PharmaBackend.exe
            # exe_dir = C:/projet/backend/dist
            # parent_dir = C:/projet/backend
            # On doit remonter encore pour atteindre C:/projet/
            project_root = os.path.dirname(parent_dir)  # Remonter de "backend" vers le projet
            frontend_dist = os.path.join(project_root, "frontend", "dist")
            print(f"[*] Mode: DÉVELOPPEMENT (backend frozen)")
            print(f"[DEBUG] project_root: {project_root}")
            print(f"[DEBUG] frontend_dist (projet/frontend/dist): {frontend_dist}")
    else:
        # Mode standalone PyInstaller
        frontend_dist = os.path.join(sys._MEIPASS, "frontend_dist")
        print(f"[DEBUG] Mode standalone - frontend_dist: {frontend_dist}")
else:
    # Mode développement (Python script direct)
    frontend_dist = os.path.join(os.path.dirname(os.path.dirname(__file__)), "frontend", "dist")
    print(f"[DEBUG] Mode développement (script) - frontend_dist: {frontend_dist}")

print(f"[*] Frontend path résolu: {frontend_dist}")
print(f"[*] Frontend path existe: {os.path.exists(frontend_dist)}")

index_html_path = os.path.join(frontend_dist, "index.html")
print(f"[*] index.html path: {index_html_path}")
print(f"[*] index.html existe: {os.path.exists(index_html_path)}")

if os.path.exists(frontend_dist) and not os.path.exists(index_html_path):
    print(f"[WARNING] Le dossier frontend existe mais index.html est manquant")
    try:
        print(f"[WARNING] Contenu du dossier: {os.listdir(frontend_dist)}")
    except Exception as e:
        print(f"[ERROR] Impossible de lister le contenu: {e}")

if (
    os.path.exists(frontend_dist)
    and os.path.exists(index_html_path)
):
    print("[OK] Frontend trouvé et prêt à être servi!")

    assets_path = os.path.join(frontend_dist, "assets")
    if os.path.exists(assets_path):
        app.mount(
            "/assets",
            StaticFiles(directory=assets_path),
            name="assets"
        )
        print(f"[OK] Assets montés depuis: {assets_path}")

    # Custom 404 handler for SPA
    # If a route is not found (and not an API/asset path), serve index.html
    from fastapi.exceptions import HTTPException
    from starlette.exceptions import HTTPException as StarletteHTTPException

    @app.exception_handler(404)
    async def spa_404_handler(request, exc):
        path = request.url.path
        # If it's an API route, doc, or asset that is missing, return actual 404
        if path.startswith("/api") or path.startswith("/docs") or path.startswith("/redoc") or path.startswith("/assets") or path.startswith("/openapi.json"):
            return JSONResponse({"detail": "Not found"}, status_code=404)
        
        # Otherwise serve index.html (React Router will handle the rest)
        return FileResponse(os.path.join(frontend_dist, "index.html"))

else:
    print("[WARNING] Frontend dist folder not found. Running API only.")
    print(f"[WARNING] Chemin recherché: {frontend_dist}")
    if os.path.exists(frontend_dist):
        print(f"[WARNING] Le dossier existe mais index.html est manquant")
        try:
            print(f"[WARNING] Contenu du dossier: {os.listdir(frontend_dist)}")
        except Exception as e:
            print(f"[ERROR] Impossible de lister le contenu: {e}")

# =========================
# DESKTOP LAUNCHER
# =========================

def find_free_port(start=8000, end=8200):
    for port in range(start, end):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            if s.connect_ex(("127.0.0.1", port)) != 0:
                return port
    raise RuntimeError("No free port available")

def is_port_in_use(port):
    """Check if a port is already in use."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(("127.0.0.1", port)) == 0

def kill_process_on_port(port):
    """Kill any process using the specified port (Windows only)."""
    try:
        # Simple approach: kill all PharmaBackend processes
        subprocess.run(
            ["taskkill", "/F", "/IM", "PharmaBackend.exe"],
            capture_output=True, timeout=5,
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        )
        time.sleep(2)
        return True
    except Exception as e:
        print(f"[WARNING] Could not kill process on port {port}: {e}")
    return False

def run_api(port):
    uvicorn.run(
        app,
        host="127.0.0.1",
        port=port,
        reload=False,
        log_config=None
    )

# =========================
# MAIN ENTRY
# =========================

if __name__ == "__main__":
    # Détecter si lancé en mode frozen (exécutable)
    IS_FROZEN = getattr(sys, "frozen", False)
    
    # Par défaut, on force le port 8000 pour la production
    PORT = 8000
    
    print(f"[*] ===== DEMARRAGE DE PHARMAGESTION BACKEND =====")
    print(f"[*] Frozen mode: {IS_FROZEN}")
    print(f"[*] Target Port: {PORT}")

    if IS_FROZEN:
        print(f"[*] Demarrage en mode PRODUCTION (Frozen)")
        
        # Kill any existing process on port 8000
        if is_port_in_use(PORT):
            print(f"[WARNING] Port {PORT} already in use, attempting to free it...")
            kill_process_on_port(PORT)
            time.sleep(1)
            if is_port_in_use(PORT):
                print(f"[ERROR] Could not free port {PORT}")
        
        print(f"[*] Le serveur ecoute sur http://127.0.0.1:{PORT}")
        try:
            uvicorn.run(
                app,
                host="127.0.0.1",
                port=PORT,
                reload=False,
                log_config=None,
                access_log=False,
            )
        except Exception as e:
            print(f"[ERROR] CRITICAL: Failed to start server on port {PORT}")
            print(f"[ERROR] Detail: {e}")
            raise
            
    else:
        # Mode développement (python main.py)
        try:
            PORT = 8000
            print(f"[*] Demarrage en mode DEV sur port {PORT}")
            uvicorn.run(
                "main:app",
                host="127.0.0.1",
                port=PORT,
                reload=True
            )
        except OSError:
            PORT = find_free_port()
            print(f"[*] Port 8000 occupe, bascule sur {PORT}")
            run_api(PORT)
