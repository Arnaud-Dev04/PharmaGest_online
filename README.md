# 🏥 Pharmacy Management System

Système complet de gestion de pharmacie avec backend FastAPI (Python) et frontend Flutter (Dart).

## 📋 Vue d'ensemble

Ce projet est un système de gestion de pharmacie complet avec :

- **Backend** : API REST en Python/FastAPI avec support dual-database (SQLite offline + MySQL online)
- **Frontend** : Application Flutter multiplateforme (Windows, Web, Android)
- **Fonctionnalités** : Gestion de stock, POS, ventes, rapports, utilisateurs, synchronisation offline/online

## 🏗️ Structure du Projet

```
Pharma_logiciels_version_01/
├── backend/              # API FastAPI (Python)
│   ├── app/             # Application principale
│   │   ├── models/      # Modèles de données
│   │   ├── routes/      # Endpoints API
│   │   ├── services/    # Logique métier
│   │   ├── database/    # Configuration DB
│   │   └── auth/        # Authentification JWT
│   ├── main.py          # Point d'entrée FastAPI
│   ├── requirements.txt # Dépendances Python
│   └── README.md        # Documentation backend
│
├── frontend1/           # Application Flutter
│   ├── lib/
│   │   ├── core/        # Configuration, thème
│   │   ├── models/      # Modèles de données
│   │   ├── services/    # Services API
│   │   ├── screens/     # Écrans de l'application
│   │   ├── providers/   # Gestion d'état (Provider)
│   │   └── widgets/     # Widgets réutilisables
│   ├── pubspec.yaml     # Dépendances Flutter
│   └── README.md        # Documentation frontend
│
└── README.md            # Ce fichier
```

## 🚀 Démarrage Rapide

### Prérequis

- **Backend** :
  - Python 3.10.11
  - MySQL (XAMPP recommandé pour Windows)
  - pip (gestionnaire de paquets Python)

- **Frontend** :
  - Flutter SDK 3.10.4+
  - Dart SDK
  - Android Studio / VS Code (optionnel)

### Installation Backend

```bash
cd backend
python -m venv venv
venv\Scripts\activate  # Windows
# ou: source venv/bin/activate  # Linux/Mac

pip install -r requirements.txt

# Créer le fichier .env (voir backend/README.md)
python -c "from app.database.core import init_local_db; init_local_db()"

# Lancer le serveur
uvicorn main:app --reload
```

L'API sera accessible sur : `http://localhost:8000`

### Installation Frontend

```bash
cd frontend1
flutter pub get

# Lancer l'application
flutter run
```

## 📚 Documentation

- **Backend** : Voir [`backend/README.md`](backend/README.md)
- **Frontend** : Voir [`frontend1/README.md`](frontend1/README.md)

## 🔧 Fonctionnalités

### ✅ Backend (FastAPI)

- ✅ Authentification JWT
- ✅ Gestion de stock et fournisseurs
- ✅ Point de vente (POS)
- ✅ Gestion des ventes et historique
- ✅ Dashboard avec statistiques
- ✅ Rapports (PDF/Excel)
- ✅ Gestion des utilisateurs et rôles
- ✅ Support offline/online (SQLite + MySQL)
- ✅ Système de licence

### ✅ Frontend (Flutter)

- ✅ Interface moderne avec Material Design
- ✅ Authentification sécurisée
- ✅ Gestion de stock
- ✅ Point de vente
- ✅ Dashboard interactif avec graphiques
- ✅ Rapports et export
- ✅ Support multilingue (FR/EN)
- ✅ Thème clair/sombre

## 🔐 Sécurité

- Authentification JWT
- Hashage des mots de passe (bcrypt)
- Stockage sécurisé des tokens (FlutterSecureStorage)
- Gestion des rôles (Super Admin, Admin, Pharmacist)
- Validation des entrées côté serveur

## 🗄️ Base de Données

- **SQLite** : Base locale pour mode offline
- **MySQL** : Base distante pour synchronisation online
- **Modèles** : Utilisateurs, Médicaments, Ventes, Fournisseurs, Clients, etc.

## 🌍 Internationalisation

Support multilingue :
- 🇫🇷 Français (FR)
- 🇬🇧 Anglais (EN)

## 📦 Technologies Utilisées

### Backend
- FastAPI 0.104.1
- SQLAlchemy 2.0.23
- Pydantic 2.5.0
- Python-JOSE (JWT)
- ReportLab (PDF)
- OpenPyXL (Excel)

### Frontend
- Flutter 3.10.4+
- Provider (State Management)
- Dio (HTTP Client)
- Flutter Secure Storage
- FL Chart (Graphiques)
- Google Fonts

## 🛠️ Développement

### Structure Backend

```
backend/app/
├── models/      # Modèles SQLAlchemy
├── routes/      # Endpoints API FastAPI
├── services/    # Logique métier
├── schemas/     # Schémas Pydantic (validation)
├── database/    # Configuration DB
├── auth/        # Authentification JWT
└── utils/       # Utilitaires
```

### Structure Frontend

```
frontend1/lib/
├── core/        # Configuration, thème, constantes
├── models/      # Modèles de données
├── services/    # Services API
├── screens/     # Écrans de l'application
├── providers/   # State management (Provider)
└── widgets/     # Widgets réutilisables
```

## 📝 Licence

[Spécifier votre licence]

## 👥 Contributeurs

[Liste des contributeurs]

## 📞 Support

Pour toute question ou problème, contactez [votre email/contact].

---

**Version** : 1.0.0  
**Dernière mise à jour** : 2025-01-17


