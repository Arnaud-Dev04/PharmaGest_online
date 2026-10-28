# 💊 PharmaGestion — Plateforme Complète de Gestion de Pharmacie (Multi-Tenant, Hors-Ligne & Conforme OBR EBMS)

[![FastAPI](https://img.shields.io/badge/Backend-FastAPI-009688.svg?style=flat-square&logo=fastapi)](https://fastapi.tiangolo.com)
[![Flutter](https://img.shields.io/badge/Frontend-Flutter-02569B.svg?style=flat-square&logo=flutter)](https://flutter.dev)
[![Python](https://img.shields.io/badge/Python-3.11%2B-blue.svg?style=flat-square&logo=python)](https://python.org)
[![Database](https://img.shields.io/badge/Database-SQLite%20%7C%20MySQL-orange.svg?style=flat-square&logo=mysql)](https://mysql.com)
[![Architecture](https://img.shields.io/badge/Architecture-Multi--Tenant%20%7C%20Offline--First-success.svg?style=flat-square)](#)
[![Fiscalité OBR](https://img.shields.io/badge/Fiscalit%C3%A9-OBR%20EBMS%20Burundi-8A2BE2.svg?style=flat-square)](#5-conformité-fiscale-obr-burundi--facturation-électronique-ebms)

> **PharmaGestion** est une solution moderne, modulaire et hautement disponible conçue pour automatiser et sécuriser l'intégralité des opérations d'une officine pharmaceutique ou d'un réseau d'officines.
>
> Alliant la flexibilité du **Cloud** pour la centralisation, la résilience d'un moteur **Offline-First (hors-ligne)** pour continuer à vendre même sans Internet, et l'intégration native de la **facturation électronique fiscale certifiée OBR (Office Burundais des Recettes - EBMS)** avec QR Code et signature cryptographique.

---

## 📑 Sommaire

1. [Vue d'Ensemble & Architecture](#1-vue-densemble--architecture)
2. [Fonctionnement de la Plateforme & Modèle Multi-Tenant](#2-fonctionnement-de-la-plateforme--modèle-multi-tenant)
   - *Comment les pharmacies fonctionnent différemment et en toute isolation*
3. [Guide Métier Pas-à-Pas](#3-guide-métier-pas-à-pas)
   - [A. Enregistrement des Médicaments & Fiscalité](#a-enregistrement-des-médicaments--fiscalité)
   - [B. Approvisionnement des Médicaments (Achats, Commandes & Réception FEFO)](#b-approvisionnement-des-médicaments-achats-commandes--réception-fefo)
   - [C. Vente au Comptoir, Tiers-Payant & Encaissement (POS)](#c-vente-au-comptoir-tiers-payant--encaissement-pos)
4. [Conformité Fiscale OBR Burundi & Facturation Électronique EBMS](#4-conformité-fiscale-obr-burundi--facturation-électronique-ebms)
   - *Cadre réglementaire, intégration API, signature locale et synchronisation*
5. [Catalogue Exhaustif des Fonctionnalités](#5-catalogue-exhaustif-des-fonctionnalités)
6. [Fonctionnement Hors-Ligne (Offline-First) & Synchronisation Hybride](#6-fonctionnement-hors-ligne-offline-first--synchronisation-hybride)
7. [Architecture Technique & Stack](#7-architecture-technique--stack)
8. [Installation & Guide de Démarrage](#8-installation--guide-de-démarrage)
9. [Variables d'Environnement & Configuration](#9-variables-denvironnement--configuration)
10. [Déploiement en Production](#10-déploiement-en-production)

---

## 1. Vue d'Ensemble & Architecture

PharmaGestion repose sur une architecture découplée pensée pour la résilience opérationnelle et la conformité fiscale :

```
┌────────────────────────────────────────────────────────────────────────┐
│                   CLIENT FRONTEND (Flutter)                           │
│     Desktop (Windows)  •  Web (Navigateur)  •  Tablette / Mobile       │
│  - Point de vente ultra-rapide (Lecteur code-barres / Écran tactile)  │
│  - Factures PDF normalisées avec QR Code OBR & Signature fiscale      │
│  - Tableaux de bord de réconciliation fiscale et de stocks            │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Requêtes REST / JSON
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                     BACKEND API (FastAPI)                             │
│  - Contexte Tenant Injecté (Isolation stricte par pharmacy_id)        │
│  - Moteur POS & Clôture de caisse quotidienne (Rapport Z)             │
│  - Moteur de Stocks & Traçabilité des Lots (FEFO / FIFO)              │
│  - Client Fiscal OBR EBMS (Signature, QR Code, Validation directe)    │
│  - TaxCalculator (Calcul automatique HT / TVA 0%-18% / Prélèvements)   │
└──────────────────┬────────────────────────────────┬────────────────────┘
                   │                                │
                   ▼                                ▼
┌───────────────────────────────────┐    ┌───────────────────────────────┐
│       MODE LOCAL HORS-LIGNE       │    │          CLOUD SAAS           │
│   Base SQLite embarquée           │    │   MySQL / MariaDB centralisée │
│   - Ventes locales ininterrompues │    │   (Multi-tenant, Reporting)   │
│   - Signature fiscale locale      │    │   - Consolidation comptable   │
│   - File d'attente OBR & Sync     │    │   - Gestion de réseau/chaîne  │
└─────────────────▲─────────────────┘    └──────────────▲────────────────┘
                  └────────── Synchronisation ──────────┘
                              (Idempotente & Sécurisée)
```

---

## 2. Fonctionnement de la Plateforme & Modèle Multi-Tenant

### Pourquoi et comment les pharmacies fonctionnent-elles différemment ?

Dans un modèle SaaS ou de réseau, chaque pharmacie partenaire est une entité juridique, fiscale et commerciale 100% indépendante :

| Dimension Métier | Différenciation par Pharmacie |
| :--- | :--- |
| **Identifiants Légaux & Fiscaux (OBR)** | Chaque officine possède son propre **NIF (Numéro d'Identification Fiscale)**, son **Numéro de Registre de Commerce (RC)**, son centre fiscal d'attachement (**DMC, DPMC**) et ses propres clés d'API auprès de l'OBR (`obr_system_id`, `obr_api_username`, `obr_api_password`). |
| **Politique Tarifaire & Marges** | Prix d'achat négociés différents selon le volume ; marges et prix de vente libres ou encadrés ; monnaies paramétrables (FBu, FCFA, USD, etc.). |
| **Catalogue & Gamme de Produits** | Références propres à la zone (spécialités importées, parapharmacie, produits pédiatriques, consommables médicaux). |
| **Assurances & Tiers-Payant** | Conventions locales différentes (mutuelles d'entreprises, assurances privées, caisses nationales de santé). |
| **Organisation & Équipes** | Utilisateurs locaux (titulaires, adjoints, préparateurs, caissiers), sessions de caisse distinctes et gestion des fonds de caisse indépendante. |
| **Régime Fiscal Activé** | Activation ou non du module fiscal OBR (`obr_enabled: true/false`) et choix de l'environnement (`sandbox` pour tests ou `production`). |

### Comment PharmaGestion garantit cette étanchéité (Multi-Tenant) ?

1. **Isolation Stricte au Niveau des Données (`pharmacy_id`) :**
   - Chaque table métier (`medicaments`, `stocks`, `lots`, `fournisseurs`, `commandes`, `ventes`, `clients`, `lignes_vente`, etc.) est partitionnée par une clé étrangère `pharmacy_id`.
   - L'ORM SQLAlchemy applique un filtre automatique sur chaque requête de lecture, d'écriture et de mise à jour à partir de l'utilisateur authentifié.
   - **Zéro fuite de données :** Il est techniquement impossible pour la pharmacie A d'accéder aux ventes, aux factures OBR ou aux stocks de la pharmacie B.

2. **Séparation des Rôles (RBAC) :**
   - **`PLATFORM_ADMIN` (Super Administrateur SaaS) :** Supervise la création de nouvelles pharmacies (onboarding), gère les abonnements, monitore la santé globale de l'infrastructure et de la synchronisation.
   - **`ADMIN_PHARMACIE` (Pharmacien Titulaire / Gérant) :** Configure sa propre officine, ses accès OBR, crée ses utilisateurs, définit les règles de marge, consulte les bilans financiers.
   - **`PHARMACIEN` / `GESTIONNAIRE_STOCK` :** Gère les commandes, réceptionne les approvisionnements, valide les inventaires.
   - **`CAISSIER` / `VENDEUR` :** Accède uniquement au Point de Vente (POS), à la création de clients et à sa propre session de caisse.

---

## 3. Guide Métier Pas-à-Pas

### A. Enregistrement des Médicaments & Fiscalité

L'enregistrement d'un médicament dans le catalogue de la pharmacie associe à la fois les informations cliniques, logistiques et fiscales requises par l'OBR.

```
  ┌───────────────────────┐       ┌───────────────────────┐       ┌──────────────────────┐
  │  1. Données Produit   │  ──▶  │  2. Tarifs & Taxes    │  ──▶  │  3. Seuils de Stock  │
  │  DCI, Forme, Dosage,  │       │  Prix Achat, Marge,   │       │  Stock Min, Alertes, │
  │  Code-barres / CIP    │       │  TVA (0%/18%), Cat OBR│       │  Sur ordonnance ?    │
  └───────────────────────┘       └───────────────────────┘       └──────────────────────┘
```

#### Étapes de création dans le système :
1. **Accéder au Répertoire :** Se rendre dans le menu `Médicaments` > `Nouveau Médicament`.
2. **Identification du Produit :**
   - **Nom commercial :** Ex. *Paracétamol Biogaran* ou *Amoxicilline 500mg*.
   - **DCI (Dénomination Commune Internationale) :** Ex. *Paracétamol*, *Amoxicilline*.
   - **Code-barres / CIP :** Scanné directement avec le lecteur code-barres (douchette) ou saisi manuellement.
   - **Forme galénique & Dosage :** Comprimé, sirop, injectable, gélule ; 500mg, 1g, etc.
   - **Famille thérapeutique :** Antalgique, Antibiotique, Anti-inflammatoire, etc.
3. **Paramétrage Financier & Fiscalité OBR :**
   - **Prix d'Achat Référence (HT) :** Coût d'acquisition auprès du grossiste.
   - **Taux de marge / Coefficient multiplicateur :** Le système calcule le prix de vente suggéré.
   - **Prix de Vente Public (TTC) :** Prix appliqué au comptoir.
   - **Catégorie Fiscale OBR (`tax_category`) :**
     - `exempt` (Exonéré de TVA - Cas standard de la majorité des médicaments essentiels, Taux 0%).
     - `standard` (Taux de TVA standard, ex. 18% pour les cosmétiques, compléments et parapharmacie).
   - **Taxes complémentaires :** Taxe de consommation (`item_ct`) et taxe de loterie/prélèvements (`item_tl`) si applicables.
4. **Politique de Stock & Prescription :**
   - **Stock Minimum d'Alerte :** Seuil déclenchant les alertes de réapprovisionnement.
   - **Type de délivrance :** Vente libre (OTC) ou sur ordonnance obligatoire.

---

### B. Approvisionnement des Médicaments (Achats, Commandes & Réception FEFO)

L'approvisionnement permet d'alimenter les stocks en assurant la traçabilité complète des lots et des dates de péremption.

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  1. Détection    │ ──▶ │  2. Commande     │ ──▶ │  3. Réception    │ ──▶ │  4. Mise en      │
│  du besoin       │     │  au Fournisseur  │     │  & Contrôle Lots │     │     Rayon/Stock  │
│  (Stock mini/IA) │     │  (Bon d'achat)   │     │  (BL & DLUO)     │     │  (Calcul FIFO)   │
└──────────────────┘     └──────────────────┘     └──────────────────┘     └──────────────────┘
```

#### Cycle détaillé de l'approvisionnement :
1. **Identification du besoin :** Le système liste les médicaments dont le stock actuel est inférieur ou égal au stock d'alerte, ou utilise l'algorithme prédictif basé sur l'historique de consommation.
2. **Émission du Bon de Commande (Purchase Order) :** Choix du grossiste répartiteur ou laboratoire, ajout des références et quantités, génération du bon de commande PDF.
3. **Réception de la Livraison & Pointage :**
   - Contrôle physique des colis et pointage des quantités réelles livrées.
   - **Saisie obligatoire des informations de traçabilité :**
     - **Numéro de Lot fabricant :** Ex. `LOT-2026-X89`.
     - **Date Limite d'Utilisation Optimale (DLUO / Péremption) :** Ex. `2028-11-30`.
     - **Prix d'achat unitaire réel :** Permet la mise à jour automatique du Coût Unitaire Moyen Pondéré (CUMP).
4. **Intégration en Stock & Règle FEFO :**
   - Les articles sont injectés en rayon.
   - Le système indexe le lot pour que lors de chaque vente, le lot qui expire le plus tôt sorte en priorité (**FEFO** : First Expired, First Out).

---

### C. Vente au Comptoir, Tiers-Payant & Encaissement (POS)

Le module Point de Vente (POS) combine rapidité au comptoir et fiscalisation instantanée :

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  1. Scan Produit │ ──▶ │  2. Tiers-Payant │ ──▶ │  3. Calcul Taxes │ ──▶ │  4. Signature    │
│  & Déstock FEFO  │     │  & Remises       │     │  & Encaissement  │     │  OBR + Ticket QR │
└──────────────────┘     └──────────────────┘     └──────────────────┘     └──────────────────┘
```

#### Déroulement d'une vente en caisse :
1. **Ouverture de session de caisse :** Saisie du montant du fond de caisse initial par le caissier.
2. **Sélection des articles :** Scan douchette du code-barres ou recherche DCI/nom. Déstockage automatique du lot à péremption la plus proche.
3. **Application du Tiers-Payant / Assurances :**
   - Sélection du client et de son organisme d'assurance (ex. Ascoma, Gras Savoye, CNAM, etc.).
   - Calcul automatique de la part assurance (ex. 80%) et du ticket modérateur à la charge du patient (ex. 20%).
4. **Calcul Fiscal Automatique (`TaxCalculator`) :**
   - Ventilation automatique en HT (`price_nvat`), TVA (`vat_amount`) et TTC (`price_wvat`).
5. **Encaissement Multi-Moyens :**
   - Espèces (avec calcul automatique de monnaie à rendre).
   - Mobile Money (Wave, Lumicash, EcoCash, Orange Money, MTN MoMo).
   - Carte Bancaire, Bon de prise en charge, Crédit client enregistré.
6. **Certification OBR & Impression Ticket :**
   - Le système génère la signature électronique fiscale et le QR code de conformité.
   - Impression directe du ticket de caisse thermique (80mm ou 58mm) ou de la facture A4.
7. **Clôture de Caisse (Rapport Z) :** Rapprochement physique vs théorique en fin de poste.

---

## 4. Conformité Fiscale OBR Burundi & Facturation Électronique EBMS

PharmaGestion intègre un module de facturation fiscale certifié conforme aux exigences de l'**Office Burundais des Recettes (OBR)** et de son système **EBMS (Electronic Billing Machine System)**.

```
                    ┌──────────────────────────────────────────────┐
                    │           VENTE FINALISÉE (POS)              │
                    └──────────────────────┬───────────────────────┘
                                           │
                                           ▼
                    ┌──────────────────────────────────────────────┐
                    │          MOTEUR FISCAL (TaxCalculator)       │
                    │   Ventilation TVA 0% / 18% & Hors-Taxes      │
                    └──────────────────────┬───────────────────────┘
                                           │
                        Liaison Internet   │ Active ?
                                ┌──────────┴──────────┐
                                │                     │
                             OUI                     NON
                                │                     │
                                ▼                     ▼
                    ┌──────────────────────┐  ┌──────────────────────┐
                    │    APPEL API OBR     │  │   SIGNATURE LOCALE   │
                    │  (ebms.obr.gov.bi)   │  │   Empreinte SHA256   │
                    │  Attribution N° OBR  │  │   obr_sync: pending  │
                    │  obr_sync: synced    │  │   "SIGNÉ LOCAL"      │
                    └──────────┬───────────┘  └──────────┬───────────┘
                               │                         │
                               └───────────┬─────────────┘
                                           │
                                           ▼
                    ┌──────────────────────────────────────────────┐
                    │       GÉNÉRATION TICKET / FACTURE PDF        │
                    │  - QR Code Officiel de vérification          │
                    │  - N° Enregistrement Fiscal OBR              │
                    │  - Signature Électronique                    │
                    │  - NIF & Centre Fiscal de l'officine         │
                    └──────────────────────────────────────────────┘
```

### 1. Paramétrage Fiscal de la Pharmacie
Dans `Paramètres` > `Configuration Fiscale OBR` :
- **NIF (Numéro d'Identification Fiscale) :** Identifiant fiscal unique de l'officine.
- **N° Registre de Commerce (RC) :** Référence d'enregistrement commercial.
- **Centre Fiscal :** Centre gestionnaire des impôts (ex. `DMC`, `DPMC`).
- **Environnement OBR :** 
  - `sandbox` : Tests et validation d'homologation sur `https://ebms-test.obr.gov.bi:8443/ebms_api`
  - `production` : Émission réelle des factures fiscales sur `https://ebms.obr.gov.bi:8443/ebms_api`
- **Identifiants API OBR :** `obr_system_id`, `obr_api_username` et `obr_api_password`.

### 2. Ventilation des Taxes Médicaments vs Parapharmacie
L'OBR impose une distinction stricte des catégories fiscales :
- **Médicaments sous ordonnance & essentiels :** Catégorie `exempt` (TVA 0%, le prix HT est égal au prix TTC).
- **Produits de parapharmacie, cosmétiques & diététique :** Catégorie `standard` (TVA standard à 18%, prix HT = Prix TTC / 1.18).
- Le moteur de vente applique automatiquement cette ventilation sans que le caissier n'ait à faire de calcul manuel.

### 3. Résilience en Mode Hors-Ligne (Signature Locale & Rattrapage)
En cas de coupure de réseau ou d'indisponibilité temporaire du serveur de l'OBR :
- La vente **n'est jamais bloquée**.
- PharmaGestion génère une **signature électronique locale sécurisée** basée sur le NIF, le code facture, le montant et une empreinte cryptographique SHA-256.
- Le ticket porte la mention de conformité `SIGNÉ LOCAL`.
- La facture est enregistrée avec le statut `obr_sync_status = "pending"`.
- Dès le retour de la connexion, le système ou le bouton **"Retransmettre les factures OBR"** téléverse automatiquement l'ensemble des factures en attente vers l'OBR (`POST /obr/resync-pending`).

### 4. Mentions Légales & QR Code sur les Factures
Conformément au cahier des charges de l'OBR, chaque ticket de caisse et facture généré par PharmaGestion comporte :
- Le bandeau légal : `CONFORME EBMS - OBR BURUNDI`
- Le **QR Code officiel** scannable par les agents du fisc ou les clients pour contrôler l'authenticité de la facture sur le portail OBR.
- Le N° d'enregistrement fiscal OBR (`obr_invoice_number`).
- La signature électronique certifiée (`obr_signature`).
- Le NIF du client s'il s'agit d'une institution ou d'une entreprise conventionnée.

### 5. Endpoints de Supervision OBR
- `POST /obr/test-connection` : Teste la validité des accès API et la joignabilité du serveur OBR.
- `GET /obr/status` : Affiche les compteurs en temps réel (factures transmises, en attente, erreurs).
- `POST /obr/resync-pending` : Retransmet par lots (batch) les factures différées.

---

## 5. Catalogue Exhaustif des Fonctionnalités

### 🛒 1. Point de Vente & Caisse (POS)
- Recherche ultra-rapide par code-barres, DCI ou nom commercial.
- Paniers multiples en attente.
- Gestion des remises autorisées avec contrôle par rôle.
- Historique des ventes, réimpression de tickets et annulations avec piste d'audit.
- Gestion de plusieurs caisses physiques en simultané dans la même pharmacie.

### 📦 2. Gestion des Stocks, Lots & Alertes FEFO
- Sortie de stock selon la méthode **FEFO** (First Expired, First Out).
- Traçabilité totale par lot fabricant et date de péremption (DLUO).
- Tableau de bord des alertes de péremption (90, 60, 30 jours et produits périmés).
- Module d'inventaire périodique ou tournant avec calcul des écarts et régularisation.

### 🚚 3. Achats & Relations Fournisseurs
- Répertoire des grossistes répartiteurs et laboratoires.
- Suivi du cycle complet d'achat : *Brouillon*, *Commandé*, *Partiellement reçu*, *Réceptionné*.
- Historique d'évolution des prix d'achat par fournisseur et calcul du CUMP.
- Échéancier de règlement des factures fournisseurs.

### 🏥 4. Assurances, Mutuelles & Tiers-Payant
- Gestion des conventions de tiers-payant et taux de prise en charge paramétrables.
- Génération des bordereaux de facturation périodiques pour transmission aux mutuelles.
- Suivi des créances et lettrage des règlements d'assurance.

### 👥 5. Gestion des Clients & Crédits
- Fichier patient complet avec historique des délivrances et ordonnances archivées.
- Enregistrement des NIF clients pour factures institutionnelles conformes OBR.
- Suivi des comptes crédits clients avec plafonds d'endettement.

### 📊 6. Tableaux de Bord, Rapports & Analyses
- Chiffre d'affaires en temps réel (jour, semaine, mois, année).
- Marge brute réelle par médicament, famille et période.
- Top des ventes (produits les plus rentables, plus forte rotation).
- Détection des produits dormants (sur-stockage immobilisant la trésorerie).
- Exports comptables complets aux formats Excel, CSV et PDF.

---

## 6. Fonctionnement Hors-Ligne (Offline-First) & Synchronisation Hybride

1. **Vente Continue :** L'encaissement et l'impression des tickets reposent sur la base SQLite locale. Les coupures Internet n'interrompent jamais le service au comptoir.
2. **File d'Attente de Synchronisation :** Les événements de vente, mouvements de stocks et signatures fiscales locales sont consignés dans une table d'événements.
3. **Réconciliation Idempotente :**
   - Les identifiants universels uniques (UUID) empêchent tout doublon de facture lors de la reconnexion au Cloud MySQL.
   - Les factures locales sont envoyées au Cloud MySQL et à l'API OBR dès la reprise du réseau.
   - Les nouveaux catalogues ou tarifs définis sur le Cloud redescendent automatiquement vers le client local.

---

## 7. Architecture Technique & Stack

### Backend
- **Langage :** Python 3.11+
- **Framework :** [FastAPI](https://fastapi.tiangolo.com) (haute performance, validation asynchrone).
- **ORM :** [SQLAlchemy 2.0](https://www.sqlalchemy.org) avec filtres automatiques tenant (`pharmacy_id`).
- **Migrations :** [Alembic](https://alembic.sqlalchemy.org) (migrations progressives multi-tenant et fiscales).
- **Authentification :** JWT (JSON Web Tokens) avec hachage Passlib / bcrypt et refresh tokens.
- **Client HTTP :** `requests` / `httpx` pour les communications API avec l'OBR.
- **Bases de données :**
  - Cloud / Production : MySQL 8.0+ / MariaDB 10.5+
  - Local / Caisse : SQLite 3 (mode WAL activé)

### Frontend
- **Framework :** [Flutter 3.x](https://flutter.dev) (Dart).
- **Plateformes cibles :** Windows Desktop natif (.exe), Web SPA (HTML5/CanvasKit), Android (.apk).
- **Génération PDF :** Packages `pdf` et `printing` avec rendu vectoriel de QR codes et mise en page responsive.
- **Gestion d'état :** Provider.

---

## 8. Installation & Guide de Démarrage

### Prérequis
- **Python 3.11+** installé.
- **Flutter SDK 3.x** installé.
- **Git** pour le clonage du code source.

---

### Démarrage du Backend

1. **Cloner et ouvrir le dossier backend :**
   ```bash
   cd e:\Project\PharmaGest_online\backend
   ```

2. **Créer et activer l'environnement virtuel Python :**
   ```powershell
   python -m venv venv
   .\venv\Scripts\Activate.ps1
   ```

3. **Installer les dépendances :**
   ```bash
   pip install -r requirements.txt
   ```

4. **Configurer l'environnement (`.env`) :**
   ```ini
   ENVIRONMENT=development
   DATABASE_URL=sqlite:///./pharmacy_local.db
   SECRET_KEY=cle_secrete_jwt_super_longue_et_aleatoire
   ACCESS_TOKEN_EXPIRE_MINUTES=480
   CORS_ORIGINS=["*"]
   ```

5. **Exécuter les migrations de base de données :**
   ```bash
   alembic upgrade head
   ```

6. **Lancer le serveur API :**
   ```bash
   uvicorn main:app --reload --host 127.0.0.1 --port 8000
   ```
   - Documentation interactive Swagger : `http://127.0.0.1:8000/docs`
   - Documentation Redoc : `http://127.0.0.1:8000/redoc`

---

### Démarrage du Frontend (Flutter)

1. **Aller dans le dossier frontend :**
   ```bash
   cd ..\frontend1
   ```

2. **Télécharger les packages :**
   ```bash
   flutter pub get
   ```

3. **Lancer l'application :**
   - **Sous Windows Desktop :**
     ```bash
     flutter run -d windows
     ```
   - **Dans le navigateur Chrome :**
     ```bash
     flutter run -d chrome
     ```

---

## 9. Variables d'Environnement & Configuration

| Variable | Description | Exemple |
| :--- | :--- | :--- |
| `ENVIRONMENT` | Environnement d'exécution (`development`, `staging`, `production`) | `production` |
| `DATABASE_URL` | Chaîne de connexion SQL (SQLite locale ou MySQL Cloud) | `mysql+pymysql://user:pwd@host:3306/pharma_db` |
| `SECRET_KEY` | Clé secrète de signature des jetons JWT | `votre_cle_secrete_64_bits` |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | Durée de vie d'un jeton d'authentification | `480` |
| `CORS_ORIGINS` | Origines autorisées pour les requêtes web | `["*"]` |
| `PORT` | Port d'écoute du serveur | `8000` |

---

## 10. Déploiement en Production

### 1. Déploiement Cloud Backend (Render / VPS)
Le projet intègre `render.yaml` et `render_main.py` pour un déploiement clé-en-main :
- **Build Command :** `pip install -r requirements.txt && alembic upgrade head`
- **Start Command :** `gunicorn render_main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:$PORT`

### 2. Base de Données MySQL Centralisée
- MySQL 8.0+ hébergé avec chiffrement SSL (Aiven, PlanetScale ou VPS).
- Migrations automatiques exécutées lors du déploiement via Alembic.

### 3. Compilation du Client Windows de Comptoir
```bash
cd frontend1
flutter build windows --release
```
L'exécutable autonome destiné aux ordinateurs de caisse sera généré dans :
`frontend1\build\windows\x64\runner\Release\`.

---

## 🔒 Sécurité, Fiscalité & Rôles

- **Traçabilité Sanitaire :** Respect strict de la méthode FEFO et historisation de chaque boîte délivrée.
- **Intégrité Fiscale OBR :** Impossibilité de modifier ou supprimer une facture déjà certifiée et transmise à l'OBR.
- **Contrôle d'Accès basé sur les Rôles (RBAC) :**
  - `PLATFORM_ADMIN` : Superviseur SaaS
  - `ADMIN_PHARMACIE` : Pharmacien titulaire
  - `PHARMACIEN` : Préparateur / Responsable délivrance
  - `CAISSIER` : Vendeur comptoir