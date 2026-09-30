# 🚀 Guide de Déploiement — PharmaGest Online

Ce document récapitule l'architecture complète, la configuration de chaque composant et la procédure pas-à-pas pour mettre à jour l'application en ligne.

---

## 🏛️ 1. Architecture Globale (Les 3 Piliers)

L'application repose sur une architecture Cloud 3-tiers moderne et ultra-rapide :

```
┌─────────────────────────────────┐
│     CLIENT (Utilisateur)        │
│   Navigateur Web / Mobile       │
└──────────────┬──────────────────┘
               │
               ▼ HTTPS (CDN mondial)
┌─────────────────────────────────┐
│      1. FRONTEND : VERCEL       │
│  - Flutter Web (HTML/JS/WASM)   │
│  - Hébergement statique Edge    │
│  - URL : https://*.vercel.app   │
└──────────────┬──────────────────┘
               │
               ▼ REST API (HTTPS / JSON)
┌─────────────────────────────────┐
│      2. BACKEND : RENDER        │
│  - Python 3 / FastAPI / Uvicorn │
│  - Région : Frankfurt (Europe)  │
│  - URL : https://pharmagest-pnn8.onrender.com
└──────────────┬──────────────────┘
               │
               ▼ SQL TCP+SSL (< 2 ms de latence intra-datacenter)
┌─────────────────────────────────┐
│   3. BASE DE DONNÉES : AIVEN    │
│  - MySQL 8.x Cloud géré         │
│  - Région : Europe (Francfort)  │
│  - Port SSL : 17450             │
└─────────────────────────────────┘
```

> **💡 Pourquoi l'application est rapide ?**  
> Le backend (Render) et la base de données (Aiven) sont hébergés dans la **même région (Francfort/Europe)**. La communication entre l'API et la base s'effectue en **moins de 2 millisecondes**, ce qui permet d'afficher les écrans instantanément pour l'utilisateur.

---

## 🔑 2. Coordonnées et Configuration

### A. Base de données (Aiven Cloud MySQL)
- **Hôte** : `mysql-de9b9a6-ntakiarnaud04-3b3b.k.aivencloud.com`
- **Port** : `17450`
- **Utilisateur** : `avnadmin`
- **Base de données** : `defaultdb`
- **SSL** : Requis (`ssl_mode=REQUIRED`)

### B. Backend (Render)
- **Service** : `gestpharma` (Web Service)
- **URL Publique** : `https://pharmagest-pnn8.onrender.com`
- **Documentation Swagger** : `https://pharmagest-pnn8.onrender.com/docs`
- **Région** : `Frankfurt (EU Central)`
- **Racine du projet (Root Directory)** : `backend`
- **Build Command** : `pip install -r requirements.txt`
- **Start Command** : `uvicorn render_main:app --host 0.0.0.0 --port $PORT`
- **Variables d'environnement (Render Dashboard → Environment)** :
  - `DB_URL_LOCAL` = `mysql+pymysql://avnadmin:MOT_DE_PASSE@mysql-de9b9a6-ntakiarnaud04-3b3b.k.aivencloud.com:17450/defaultdb`
  - `DB_URL_REMOTE` = `mysql+pymysql://avnadmin:MOT_DE_PASSE@mysql-de9b9a6-ntakiarnaud04-3b3b.k.aivencloud.com:17450/defaultdb`
  - `SECRET_KEY` = `pharma-gest-s3cur3-k3y-2026-render`
  - `ALLOWED_ORIGINS` = `*`

### C. Frontend (Vercel)
- **Framework Preset** : `Other`
- **Root Directory** : `frontend1`
- **Dossier de sortie (Output Directory)** : `build/web`
- **Build Command** : Désactivé (Toggle OFF)
- **Install Command** : Désactivé (Toggle OFF)
- **Lien avec le backend** : Défini dans `frontend1/lib/core/constants.dart` :
  ```dart
  static const String apiBaseUrl = 'https://pharmagest-pnn8.onrender.com';
  ```

---

## 🔄 3. Comment faire des mises à jour (Workflow quotidien)

### Cas 1 : Tu as modifié le Backend (Python / API)
Render se met à jour **automatiquement** dès que tu pousses sur GitHub :

```powershell
cd E:\Project\PharmaGest_online
git add backend/
git commit -m "feat: mise à jour backend"
git push
```
*Render détecte le commit, réinstalle et redémarre le serveur en ~2 minutes.*

---

### Cas 2 : Tu as modifié le Frontend (Flutter / Dart)
Comme Flutter est compilé en local avant d'être servi par Vercel :

```powershell
# 1. Compiler la nouvelle version Web
cd E:\Project\PharmaGest_online\frontend1
flutter build web --release --base-href /

# 2. Pousser sur GitHub
cd E:\Project\PharmaGest_online
git add .
git commit -m "feat: mise à jour interface Flutter"
git push
```
*Vercel détecte le push et déploie les nouveaux fichiers en ~10 secondes chrono.*

---

## ⚠️ 4. Points d'attention importants

1. **Cold Start sur Render (Plan Gratuit) :**
   - Sur l'offre gratuite de Render, le serveur s'endort après 15 minutes d'inactivité.
   - La première requête après une longue pause peut mettre ~30 secondes à démarrer (le temps que le conteneur se réveille).
   - Ensuite, tout redevient ultra-rapide.
   - *Astuce* : Pour éviter la mise en veille, tu peux utiliser un outil gratuit de monitoring comme [UptimeRobot](https://uptimerobot.com) qui envoie une requête GET sur `https://pharmagest-pnn8.onrender.com/health` toutes les 10 minutes, ou passer au plan Starter (\$7/mois).

2. **Sécurité des Mots de Passe :**
   - Le fichier `render.yaml` et le fichier `.env` ne doivent **jamais** contenir de mot de passe en clair dans GitHub.
   - Les mots de passe sont saisis directement dans l'interface de Render (**Settings → Environment**).

3. **Repasser en mode 100% Local (Hors-ligne / Desktop) :**
   - Si tu souhaites lancer l'application en local sans Internet :
     - Dans `backend/.env`, remets `DB_URL_LOCAL=sqlite:///./pharmacy_local.db`
     - Dans `frontend1/lib/core/constants.dart`, remets `apiBaseUrl = _localApi;`
