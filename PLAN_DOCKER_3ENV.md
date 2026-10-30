# PLAN_DOCKER_3ENV.md
# PharmaGest — Plan d'Implémentation : 3 Environnements Docker · 1 Base MySQL

> **Objectif :** Déployer PharmaGest dans 3 conteneurs FastAPI indépendants (Basic, Pro, Enterprise)
> connectés à une **seule base de données MySQL**, avec routage automatique selon le plan d'abonnement.
>
> **Durée estimée :** 4 jours · **Risque :** Faible (la BD, le JWT et le multi-tenant sont intacts)

---

## Architecture Cible

```
Flutter Web / Mobile
        │
        │  1. POST /auth/login → réponse inclut api_base_url
        │  2. Flutter stocke l'URL et pointe vers la bonne instance
        ▼
┌─────────────────────────────────────────────┐
│           Nginx (port 80 / 443)             │
│  /auth/*    → Load-balanced sur les 3      │
│  /api/*     → Instance selon X-Instance    │
└──────┬──────────────┬──────────────┬───────┘
       │              │              │
┌──────▼──────┐ ┌─────▼──────┐ ┌────▼────────┐
│ API Basic   │ │  API Pro   │ │ API Ent.    │
│ Port 8001   │ │ Port 8002  │ │ Port 8003   │
│ 1 worker    │ │ 2 workers  │ │ 4 workers   │
│ SECRET_K_1  │ │ SECRET_K_2 │ │ SECRET_K_3  │
└──────┬──────┘ └─────┬──────┘ └────┬────────┘
       └──────────────┴──────────────┘
                       │
          ┌────────────▼────────────┐
          │   MySQL (Cloud / Local)  │
          │   1 seule base · toutes  │
          │   les pharmacies isolées │
          │   par pharmacy_id        │
          └─────────────────────────┘
```

---

## Principes Clés

| Principe | Détail |
|---|---|
| **1 image Docker** | Les 3 instances partagent le même `Dockerfile` |
| **3 SECRET_KEY JWT** | Chaque instance a sa propre clé — un token Basic ne fonctionne pas sur Enterprise |
| **1 base MySQL** | `pharmacy_id` isole déjà toutes les données (architecture multi-tenant existante) |
| **Routage post-login** | Le serveur retourne `api_base_url` après login — Flutter s'adapte |
| **platform_admin exclu** | L'admin plateforme n'est pas affecté par le routage d'instance |

---

## Phase 1 — Infrastructure Docker (Jour 1)

### 1.1 Créer `backend/Dockerfile`

**Fichiers à créer :**
- `backend/Dockerfile`
- `backend/.dockerignore`

**Contenu `Dockerfile` :**
```dockerfile
FROM python:3.12-slim

WORKDIR /app

# Dépendances système minimales
RUN apt-get update && apt-get install -y --no-install-recommends \
    default-libmysqlclient-dev gcc && \
    rm -rf /var/lib/apt/lists/*

# Installation des dépendances Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copie du code source
COPY . .

# Port exposé (configurable via ENV)
EXPOSE 8000

# Commande de démarrage (workers configurables par env)
CMD uvicorn main:app --host 0.0.0.0 --port 8000 --workers ${WORKERS:-2}
```

**Contenu `.dockerignore` :**
```
venv/
__pycache__/
*.pyc
*.pyo
.env
.pytest_cache/
tests/
*.log
alembic/versions/__pycache__/
```

---

### 1.2 Créer `compose.yaml` à la racine

**Fichier à créer :** `compose.yaml`

```yaml
services:

  # ── Instance Basic (plan basic) ──────────────────────────────────
  api_basic:
    build: ./backend
    container_name: pharmagest_basic
    restart: unless-stopped
    ports:
      - "8001:8000"
    env_file:
      - ./docker/basic.env
    environment:
      INSTANCE_NAME: basic
      WORKERS: "1"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # ── Instance Pro (plan pro) ───────────────────────────────────────
  api_pro:
    build: ./backend
    container_name: pharmagest_pro
    restart: unless-stopped
    ports:
      - "8002:8000"
    env_file:
      - ./docker/pro.env
    environment:
      INSTANCE_NAME: pro
      WORKERS: "2"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # ── Instance Enterprise ───────────────────────────────────────────
  api_enterprise:
    build: ./backend
    container_name: pharmagest_enterprise
    restart: unless-stopped
    ports:
      - "8003:8000"
    env_file:
      - ./docker/enterprise.env
    environment:
      INSTANCE_NAME: enterprise
      WORKERS: "4"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # ── Nginx — Reverse Proxy & Routeur ──────────────────────────────
  nginx:
    image: nginx:alpine
    container_name: pharmagest_nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./docker/nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - api_basic
      - api_pro
      - api_enterprise
```

---

### 1.3 Créer les fichiers d'environnement par instance

**Dossier à créer :** `docker/`

**`docker/basic.env.example`** (copier en `basic.env` avec les vrais secrets) :
```env
INSTANCE_NAME=basic
WORKERS=1

# Base MySQL — MÊME pour les 3 instances
DB_URL_LOCAL=mysql+pymysql://USER:PASSWORD@HOST:PORT/pharmagest_db
DB_URL_REMOTE=mysql+pymysql://USER:PASSWORD@HOST:PORT/pharmagest_db

# JWT — SECRET UNIQUE pour cette instance
SECRET_KEY=GENERER_UNE_CLE_ALEATOIRE_INSTANCE_BASIC_256_BITS
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60
REFRESH_TOKEN_EXPIRE_DAYS=30

# App
APP_NAME=PharmaGest
ENVIRONMENT=production
DEBUG=False

# CORS
ALLOWED_ORIGINS=https://pharmagest.com,https://www.pharmagest.com

# URLs des 3 instances (pour construire api_base_url dans la réponse login)
URL_ENV_BASIC=https://basic.pharmagest.com
URL_ENV_PRO=https://pro.pharmagest.com
URL_ENV_ENTERPRISE=https://enterprise.pharmagest.com

# Admin
ADMIN_INITIAL_PASSWORD=CHANGER_EN_PRODUCTION
PLATFORM_ADMIN_USERNAME=platform_admin
PLATFORM_ADMIN_PASSWORD=CHANGER_EN_PRODUCTION
```

**`docker/pro.env.example`** — identique mais avec :
```env
INSTANCE_NAME=pro
WORKERS=2
SECRET_KEY=GENERER_UNE_CLE_ALEATOIRE_INSTANCE_PRO_256_BITS
```

**`docker/enterprise.env.example`** — identique mais avec :
```env
INSTANCE_NAME=enterprise
WORKERS=4
SECRET_KEY=GENERER_UNE_CLE_ALEATOIRE_INSTANCE_ENTERPRISE_256_BITS
```

---

### 1.4 Créer `docker/nginx.conf`

```nginx
events { worker_connections 1024; }

http {
    upstream basic_backend    { server api_basic:8000; }
    upstream pro_backend      { server api_pro:8000; }
    upstream enterprise_backend { server api_enterprise:8000; }

    server {
        listen 80;
        server_name pharmagest.com *.pharmagest.com;

        # Authentification — load-balanced sur basic (point d'entrée unique)
        location /auth/ {
            proxy_pass http://basic_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        # Santé — chaque instance exposée
        location /health {
            proxy_pass http://basic_backend;
        }

        # Instances dédiées par sous-domaine ou préfixe
        location /basic/ {
            proxy_pass http://basic_backend/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
        location /pro/ {
            proxy_pass http://pro_backend/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
        location /enterprise/ {
            proxy_pass http://enterprise_backend/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
```

**Livrable Phase 1 :** `docker compose up --build` démarre les 3 conteneurs sans erreur.

---

## Phase 2 — Backend : Routage & Middleware (Jour 2)

### 2.1 Ajouter `deployment_env` au modèle `Pharmacy`

**Fichier :** `backend/app/models/pharmacy.py`

```python
# Ajouter après le champ `plan`
deployment_env = Column(String(20), default="basic", nullable=False)
"""
Instance Docker cible pour cette pharmacie.
Valeurs : "basic" | "pro" | "enterprise"
Peut différer du plan (ex: pharmacie Pro hébergée temporairement sur Basic).
"""
```

**Migration Alembic à créer :**
```bash
alembic revision --autogenerate -m "add_pharmacy_deployment_env"
alembic upgrade head
```

---

### 2.2 Modifier la réponse `/auth/login`

**Fichier :** `backend/app/routes/auth.py`

Modifier le `return` du endpoint `login` :

```python
# Lire le plan et l'environnement de déploiement de la pharmacie
plan = "platform"
api_base_url = None

if user.pharmacy_id:
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == user.pharmacy_id).first()
    if pharmacy:
        plan = pharmacy.plan  # "basic" | "pro" | "enterprise"
        env = pharmacy.deployment_env or pharmacy.plan
        url_map = {
            "basic":      os.getenv("URL_ENV_BASIC",      "http://localhost:8001"),
            "pro":        os.getenv("URL_ENV_PRO",        "http://localhost:8002"),
            "enterprise": os.getenv("URL_ENV_ENTERPRISE", "http://localhost:8003"),
        }
        api_base_url = url_map.get(env, url_map["basic"])

return {
    "access_token": access_token,
    "refresh_token": refresh_token,
    "token_type": "bearer",
    "must_change_password": user.must_change_password,
    "is_first_setup": is_first_setup,
    # ── Nouveaux champs ──
    "plan": plan,
    "api_base_url": api_base_url,   # None pour platform_admin
    "environment": pharmacy.deployment_env if user.pharmacy_id else "platform",
}
```

---

### 2.3 Mettre à jour le schéma `Token`

**Fichier :** `backend/app/schemas/auth.py`

```python
class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str
    must_change_password: bool = False
    is_first_setup: bool = False
    # ── Nouveaux champs ──
    plan: Optional[str] = None
    api_base_url: Optional[str] = None
    environment: Optional[str] = None
```

---

### 2.4 Créer le middleware d'instance

**Fichier à créer :** `backend/app/middleware/instance_guard.py`

```python
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

    # Vérifier l'instance via header X-Instance (positionné par Nginx)
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
```

**Enregistrer dans `main.py` :**
```python
from app.middleware.instance_guard import instance_guard_middleware
from starlette.middleware.base import BaseHTTPMiddleware

app.add_middleware(BaseHTTPMiddleware, dispatch=instance_guard_middleware)
```

---

### 2.5 Ajouter un endpoint `/health`

**Fichier :** `backend/app/routes/health.py` (à créer)

```python
from fastapi import APIRouter
from app.database import check_database_connection
import os

router = APIRouter()

@router.get("/health")
def health_check():
    db_ok = check_database_connection()
    return {
        "status": "ok" if db_ok else "degraded",
        "instance": os.getenv("INSTANCE_NAME", "unknown"),
        "db": "connected" if db_ok else "unreachable",
    }
```

**Livrable Phase 2 :** Login retourne `api_base_url`. Middleware actif. `/health` répond sur les 3 instances.

---

## Phase 3 — Flutter : URL Dynamique (Jour 3)

### 3.1 Modifier `ApiService` pour supporter l'URL dynamique

**Fichier :** `frontend1/lib/services/api_service.dart`

```dart
class ApiService {
  static String _baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8001',
  );

  /// Appelé après un login réussi pour pointer vers la bonne instance
  static void setBaseUrl(String url) {
    _baseUrl = url;
    // Persistance pour les prochaines sessions
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('api_base_url', url);
    });
  }

  /// Restaure l'URL depuis SharedPreferences au démarrage
  static Future<void> restoreBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('api_base_url');
    if (saved != null && saved.isNotEmpty) {
      _baseUrl = saved;
    }
  }

  String get baseUrl => _baseUrl;
}
```

---

### 3.2 Modifier `AuthProvider` pour stocker l'URL après login

**Fichier :** `frontend1/lib/providers/auth_provider.dart`

```dart
Future<void> login(String username, String password, {String? pharmacyCode}) async {
  final response = await _authService.login(username, password, pharmacyCode: pharmacyCode);

  // ── Nouveau : stocker l'URL de l'instance ──
  if (response.apiBaseUrl != null && response.apiBaseUrl!.isNotEmpty) {
    ApiService.setBaseUrl(response.apiBaseUrl!);
  }

  // Suite du login existant...
  _token = response.accessToken;
  _user = response.user;
  notifyListeners();
}
```

---

### 3.3 Mettre à jour le modèle de réponse Auth

**Fichier :** `frontend1/lib/models/auth_response.dart` (ou équivalent)

```dart
class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final bool mustChangePassword;
  final bool isFirstSetup;
  // ── Nouveaux champs ──
  final String? plan;
  final String? apiBaseUrl;
  final String? environment;

  // ... fromJson() à mettre à jour
}
```

---

### 3.4 Restaurer l'URL au démarrage de l'app

**Fichier :** `frontend1/lib/main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  await ApiService.restoreBaseUrl();  // ← Ajouter cette ligne
  runApp(const PharmacApp());
}
```

**Livrable Phase 3 :** Flutter pointe automatiquement vers la bonne instance après login.

---

## Phase 4 — Tests de Validation (Jour 4)

### Tests Obligatoires

| # | Test | Commande / Action | Résultat Attendu |
|---|---|---|---|
| T1 | Démarrage des 3 conteneurs | `docker compose up` | Chaque API répond sur 8001, 8002, 8003 |
| T2 | Health check instances | `curl http://localhost:8001/health` | `{"status":"ok","instance":"basic"}` |
| T3 | Connexion MySQL | Chaque `/health` | `{"db":"connected"}` |
| T4 | Login pharmacie Basic | POST `/auth/login` | `api_base_url = "http://localhost:8001"` |
| T5 | Login pharmacie Pro | POST `/auth/login` | `api_base_url = "http://localhost:8002"` |
| T6 | Token Basic sur instance Pro | Appel avec token Basic vers 8002 | `401 Unauthorized` |
| T7 | Isolation des données | Pharmacie A ≠ Pharmacie B | Aucune fuite inter-tenant |
| T8 | Arrêt instance Basic | `docker stop pharmagest_basic` | Pro et Enterprise non affectées |
| T9 | Basculement de plan | Changer `deployment_env` via admin | Nouveau `api_base_url` au prochain login |
| T10 | Arrêt MySQL | Simuler timeout | Erreur 503 propre, pas de crash serveur |

---

## Sécurité — Checklist Avant Mise en Production

- [ ] Générer 3 SECRET_KEY uniques (256 bits minimum) via `openssl rand -hex 32`
- [ ] Changer `ADMIN_INITIAL_PASSWORD` dans les 3 `.env`
- [ ] Ajouter `venv/`, `docker/*.env`, `.env` dans `.gitignore`
- [ ] Ne committer que les `.env.example` (sans secrets réels)
- [ ] Activer HTTPS sur Nginx (Let's Encrypt ou certificat)
- [ ] Vérifier `ALLOWED_ORIGINS` dans chaque `.env`
- [ ] Limiter l'accès MySQL aux seules IPs des conteneurs Docker

---

## Structure Finale des Fichiers

```
PharmaGest_online/
├── backend/
│   ├── app/
│   │   ├── middleware/
│   │   │   └── instance_guard.py      ← CRÉER (Phase 2.4)
│   │   ├── models/
│   │   │   └── pharmacy.py            ← MODIFIER (Phase 2.1)
│   │   ├── routes/
│   │   │   ├── auth.py                ← MODIFIER (Phase 2.2)
│   │   │   └── health.py              ← CRÉER (Phase 2.5)
│   │   └── schemas/
│   │       └── auth.py                ← MODIFIER (Phase 2.3)
│   ├── alembic/versions/
│   │   └── XXXXXXXX_add_pharmacy_deployment_env.py  ← GÉNÉRER
│   ├── Dockerfile                     ← CRÉER (Phase 1.1)
│   └── .dockerignore                  ← CRÉER (Phase 1.1)
├── docker/
│   ├── nginx.conf                     ← CRÉER (Phase 1.4)
│   ├── basic.env.example              ← CRÉER (Phase 1.3)
│   ├── pro.env.example                ← CRÉER (Phase 1.3)
│   └── enterprise.env.example         ← CRÉER (Phase 1.3)
├── frontend1/
│   └── lib/
│       ├── main.dart                  ← MODIFIER (Phase 3.4)
│       ├── providers/
│       │   └── auth_provider.dart     ← MODIFIER (Phase 3.2)
│       └── services/
│           └── api_service.dart       ← MODIFIER (Phase 3.1)
├── compose.yaml                       ← CRÉER (Phase 1.2)
└── PLAN_DOCKER_3ENV.md                ← CE FICHIER
```

---

## Commandes de Référence

```bash
# Démarrer les 3 environnements
docker compose up --build -d

# Voir les logs d'une instance
docker logs pharmagest_pro -f

# Arrêter une instance spécifique
docker stop pharmagest_basic

# Redémarrer après une mise à jour du code
docker compose up --build api_pro -d

# Générer la migration Alembic
cd backend
alembic revision --autogenerate -m "add_pharmacy_deployment_env"
alembic upgrade head

# Générer une SECRET_KEY
openssl rand -hex 32
```

---

*Plan créé le 2026-10-29 — Version 1.0*
*À exécuter en 4 phases séquentielles. Ne pas passer à la phase suivante sans valider la précédente.*

