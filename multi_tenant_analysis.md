# 🏗️ PharmaGestion — Analyse Multi-Pharmacies (Multi-Tenant)

> Analyse de l'architecture actuelle et plan d'évolution pour supporter plusieurs pharmacies simultanément avec plusieurs utilisateurs par pharmacie.

---

## 1. État Actuel — Ce qui existe déjà ✅

### Ce que le projet a déjà de bien

| Fonctionnalité | Fichier | Status |
|---|---|---|
| Système d'authentification JWT | `backend/app/auth/dependencies.py` | ✅ Présent |
| Rôles utilisateurs (Admin, Pharmacist, Super Admin) | `backend/app/models/user.py` | ✅ Présent |
| Double DB (SQLite local + PostgreSQL remote) | `backend/app/database/core.py` | ✅ Présent |
| Sync local ↔ cloud | `backend/app/sync/sync_manager.py` | ✅ Présent |
| Audit logs | `backend/app/models/audit_log.py` | ✅ Présent |
| API REST FastAPI | `backend/app/routes/` (18 fichiers) | ✅ Présent |
| Système de licences | `backend/app/core/license.py` | ✅ Présent |

### Le problème fondamental — Architecture mono-tenant

```
État actuel :
┌─────────────────────────────────────┐
│  Une seule DB  →  Une seule pharma  │
│  users sans pharmacy_id             │
│  medicines sans pharmacy_id         │
│  sales sans pharmacy_id             │
└─────────────────────────────────────┘
```

**Aucune table `pharmacies` n'existe.** Tous les modèles (medicines, users, sales, batches...) sont globaux — ils n'appartiennent à aucune pharmacie spécifique. C'est la barrière principale à franchir.

---

## 2. Les 3 Approches Multi-Tenant

### Option A — Multi-DB (une DB par pharmacie) 🔴 Complexe
- Chaque pharmacie a sa propre base de données PostgreSQL
- **Avantages :** isolation parfaite, migration facile par client
- **Inconvénients :** coûteux (N bases = N connexions), difficile à maintenir
- **Recommandé pour :** >100 pharmacies avec exigences de confidentialité très strictes

### Option B — Schema PostgreSQL par pharmacie 🟡 Intermédiaire
- Une seule DB PostgreSQL, mais un `schema` différent par pharmacie (`pharma_001.medicines`, `pharma_002.medicines`)
- **Avantages :** bonne isolation, facile à sauvegarder par client
- **Inconvénients :** Nécessite PostgreSQL obligatoirement (incompatible SQLite local)

### Option C — `pharmacy_id` sur toutes les tables ✅ **Recommandé**
- Une seule DB, toutes les tables ont une colonne `pharmacy_id`
- Chaque requête est filtrée automatiquement par `pharmacy_id`
- **Avantages :** simple, peu coûteux, compatible SQLite + PostgreSQL, évolutif
- **Inconvénients :** il faut bien sécuriser les routes (jamais de fuite entre pharmacies)

> [!IMPORTANT]
> **L'Option C est la meilleure pour PharmaGestion** car elle préserve la compatibilité SQLite locale tout en permettant le multi-tenant cloud. C'est aussi la plus facile à implémenter progressivement.

---

## 3. Architecture Cible — Plan Complet

### 3.1 Nouveau modèle `Pharmacy`

```python
# backend/app/models/pharmacy.py  (NOUVEAU)
class Pharmacy(Base, BaseModelMixin):
    __tablename__ = "pharmacies"

    name         = Column(String(200), nullable=False)
    code         = Column(String(50), unique=True, nullable=False)  # ex: PHARMA-001
    address      = Column(String(500), nullable=True)
    phone        = Column(String(50), nullable=True)
    email        = Column(String(200), nullable=True)
    country      = Column(String(100), default="Côte d'Ivoire")
    city         = Column(String(100), nullable=True)
    is_active    = Column(Boolean, default=True)
    license_key  = Column(String(255), nullable=True)  # Lier au système de licence
    plan         = Column(String(50), default="basic")  # basic / pro / enterprise
    max_users    = Column(Integer, default=5)  # Limite d'utilisateurs par pharma

    # Relations
    users        = relationship("User", back_populates="pharmacy")
    medicines    = relationship("Medicine", back_populates="pharmacy")
    # ...
```

### 3.2 Modification du modèle `User`

```python
# Ajouter dans backend/app/models/user.py
class User(Base, BaseModelMixin):
    # ... colonnes existantes ...
    pharmacy_id = Column(Integer, ForeignKey("pharmacies.id"), nullable=True)
    # nullable=True pour le super admin global (platform admin)

    # Relation
    pharmacy = relationship("Pharmacy", back_populates="users")
```

### 3.3 Ajout de `pharmacy_id` sur tous les modèles métier

```python
# À ajouter sur : Medicine, Sale, POSSale, Batch, Supplier,
#                 Customer, RestockOrder, StockMovement, MedicinePricing...

pharmacy_id = Column(Integer, ForeignKey("pharmacies.id"), nullable=False, index=True)
pharmacy    = relationship("Pharmacy")
```

### 3.4 Nouveau système de hiérarchie des rôles

```
PLATFORM_ADMIN (super_admin)
    │  → Gérer TOUTES les pharmacies
    │  → Créer / désactiver des pharmacies
    │  → Voir les métriques globales
    │
    ├── PHARMACY_ADMIN (admin)
    │       │  → Gérer SA pharmacie seulement
    │       │  → Créer/modifier les utilisateurs de SA pharmacie
    │       │  → Voir les rapports de SA pharmacie
    │       │
    │       └── PHARMACIST (pharmacist)
    │               → POS, Stock, Ventes de SA pharmacie
    │               → Pas d'accès admin
    │
    └── PHARMACY_MANAGER (nouveau rôle optionnel)
            → Gérer plusieurs pharmacies d'une chaîne
```

### 3.5 Injection automatique du `pharmacy_id` dans les routes

```python
# backend/app/auth/dependencies.py — Modifier get_current_user

async def get_current_pharmacy_context(
    current_user: User = Depends(get_current_user)
) -> PharmacyContext:
    """Retourne le contexte pharmacie du user connecté."""
    if current_user.role == UserRole.SUPER_ADMIN:
        # Platform admin peut accéder à toutes les pharmacies
        return PharmacyContext(pharmacy_id=None, is_platform_admin=True)

    if not current_user.pharmacy_id:
        raise HTTPException(403, "Utilisateur non assigné à une pharmacie")

    return PharmacyContext(
        pharmacy_id=current_user.pharmacy_id,
        is_platform_admin=False
    )
```

```python
# Dans chaque route — Exemple route stock
@router.get("/stock")
def get_stock(
    ctx: PharmacyContext = Depends(get_current_pharmacy_context),
    db: Session = Depends(get_db)
):
    query = db.query(Medicine).filter(Medicine.pharmacy_id == ctx.pharmacy_id)
    return query.all()
```

---

## 4. Ce qui doit changer — Résumé des fichiers à modifier

### 🆕 Fichiers à CRÉER

| Fichier | Description |
|---|---|
| `backend/app/models/pharmacy.py` | Nouveau modèle Pharmacy |
| `backend/app/schemas/pharmacy.py` | Schémas Pydantic |
| `backend/app/routes/pharmacies.py` | CRUD pharmacies (platform admin) |
| `backend/app/routes/onboarding.py` | Enregistrement d'une nouvelle pharmacie |
| `backend/alembic/versions/xxx_add_pharmacy_id.py` | Migration DB |
| `frontend1/lib/models/pharmacy.dart` | Modèle Flutter |
| `frontend1/lib/screens/platform_admin/` | Interface admin plateforme |

### ✏️ Fichiers à MODIFIER

| Fichier | Modification |
|---|---|
| `backend/app/models/user.py` | Ajouter `pharmacy_id` |
| `backend/app/models/medicine.py` | Ajouter `pharmacy_id` |
| `backend/app/models/sales.py` | Ajouter `pharmacy_id` |
| `backend/app/models/pos_sale.py` | Ajouter `pharmacy_id` |
| `backend/app/models/batch.py` | Ajouter `pharmacy_id` |
| `backend/app/models/customer.py` | Ajouter `pharmacy_id` |
| `backend/app/models/supplier.py` | Ajouter `pharmacy_id` |
| `backend/app/models/restock.py` | Ajouter `pharmacy_id` |
| `backend/app/models/stock_movement.py` | Ajouter `pharmacy_id` |
| `backend/app/models/medicine_pricing.py` | Ajouter `pharmacy_id` |
| `backend/app/auth/dependencies.py` | Ajouter `PharmacyContext` |
| `backend/app/routes/*.py` (toutes les routes) | Filtrer par `pharmacy_id` |
| `backend/app/database/core.py` | Adapter init pour multi-tenant |
| `frontend1/lib/services/api_service.dart` | Envoyer `pharmacy_id` dans les headers |
| `frontend1/lib/providers/auth_provider.dart` | Stocker contexte pharmacie |

---

## 5. Stratégie de Migration (sans casser l'existant)

### Phase 1 — Fondations (2-3 semaines)
1. Créer le modèle `Pharmacy`
2. Ajouter `pharmacy_id` sur `User` (nullable)
3. Créer une "pharmacie par défaut" pour les données existantes
4. Migration Alembic : attribuer toutes les données actuelles à la pharmacie par défaut

### Phase 2 — Isolation des données (3-4 semaines)
1. Ajouter `pharmacy_id` sur tous les modèles métier
2. Modifier toutes les routes pour filtrer par `pharmacy_id`
3. Modifier le système d'auth pour inclure le contexte pharmacie dans le JWT
4. Tests complets

### Phase 3 — Interface d'administration (2-3 semaines)
1. Interface Platform Admin (créer/gérer des pharmacies)
2. Tableau de bord global (métriques de toutes les pharmacies)
3. Système d'onboarding pour une nouvelle pharmacie
4. Gestion des licences par pharmacie

### Phase 4 — Déploiement Cloud (2-4 semaines)
1. Migrer de SQLite local vers PostgreSQL cloud (Supabase ou Render)
2. Configurer le système de sync pour multi-tenant
3. Plan de tarification (Basic 3 users / Pro 10 users / Enterprise illimité)

---

## 6. Architecture Déploiement Cloud Multi-Tenant

```
                    ┌─────────────────────────────────┐
                    │       Internet / HTTPS           │
                    └──────────────┬──────────────────┘
                                   │
                    ┌──────────────▼──────────────────┐
                    │   Load Balancer (nginx/Render)   │
                    └──────────────┬──────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
     ┌────────▼───────┐  ┌────────▼───────┐  ┌────────▼───────┐
     │  FastAPI       │  │  FastAPI       │  │  FastAPI       │
     │  Instance 1    │  │  Instance 2    │  │  Instance 3    │
     └────────┬───────┘  └────────┬───────┘  └────────┬───────┘
              │                    │                    │
              └────────────────────┼────────────────────┘
                                   │
                    ┌──────────────▼──────────────────┐
                    │   PostgreSQL (Supabase/Render)   │
                    │                                  │
                    │   Table pharmacies               │
                    │   Table users (+ pharmacy_id)    │
                    │   Table medicines (+ pharma_id)  │
                    │   Table sales (+ pharmacy_id)    │
                    │   ...                            │
                    └─────────────────────────────────┘

   App Flutter (Pharmacie A)  →  Se connecte  →  Filtre auto pharmacy_id=1
   App Flutter (Pharmacie B)  →  Se connecte  →  Filtre auto pharmacy_id=2
   App Flutter (Pharmacie C)  →  Se connecte  →  Filtre auto pharmacy_id=3
```

---

## 7. Estimation de l'effort

| Phase | Durée estimée | Complexité |
|---|---|---|
| Phase 1 : Modèle Pharmacy + migration DB | 2-3 semaines | 🟡 Moyenne |
| Phase 2 : Isolation des données (routes) | 3-4 semaines | 🔴 Haute |
| Phase 3 : Interface admin plateforme | 2-3 semaines | 🟡 Moyenne |
| Phase 4 : Déploiement cloud production | 2-4 semaines | 🔴 Haute |
| **Total** | **~10-14 semaines** | — |

> [!TIP]
> La bonne nouvelle : **le système JWT, les rôles et la double DB existent déjà**. C'est une base solide. La migration la plus critique est **Phase 2** (filtrage par `pharmacy_id` dans toutes les routes) — c'est là que les bugs de fuite de données peuvent apparaître et qu'il faut être très minutieux.

---

## 8. Rôle Platform Super Admin — Gestionnaire de toutes les pharmacies

> [!IMPORTANT]
> C'est **la personne qui possède et gère le logiciel PharmaGestion**. Elle a une vue globale sur toutes les pharmacies clientes, peut les activer/désactiver, voir leurs statistiques, gérer les licences et intervenir à distance si nécessaire.

### 8.1 Qui est le Platform Super Admin ?

C'est **toi (le développeur / propriétaire du logiciel)** ou une équipe de support désignée. Il y a UNE seule interface Platform Admin, séparée de l'interface des pharmacies.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    PLATFORM SUPER ADMIN                             │
│                  (Toi — propriétaire du logiciel)                   │
│                                                                     │
│   ✅ Voir TOUTES les pharmacies (liste, statut, activité)           │
│   ✅ Créer une nouvelle pharmacie cliente                           │
│   ✅ Activer / Suspendre / Supprimer une pharmacie                  │
│   ✅ Gérer les licences (plan Basic / Pro / Enterprise)             │
│   ✅ Voir les métriques globales (nb ventes, users actifs, stock)   │
│   ✅ Réinitialiser le mot de passe admin d'une pharmacie            │
│   ✅ Se connecter EN TANT QUE une pharmacie (mode support)          │
│   ✅ Voir les logs d'erreurs de toutes les pharmacies               │
│   ✅ Envoyer des notifications à toutes les pharmacies              │
│   ✅ Gérer les mises à jour du logiciel                             │
│                                                                     │
│   ❌ Ne peut PAS modifier les données métier d'une pharmacie        │
│      (sauf en mode support explicitement activé)                    │
└─────────────────────────────────────────────────────────────────────┘
```

### 8.2 Nouveau rôle dans le modèle User

```python
# backend/app/models/user.py — Mise à jour de l'enum UserRole

class UserRole(str, enum.Enum):
    PLATFORM_ADMIN  = "platform_admin"   # 🆕 Gestionnaire du logiciel (toi)
    SUPER_ADMIN     = "super_admin"      # Admin d'une pharmacie spécifique
    PHARMACY_ADMIN  = "pharmacy_admin"   # 🆕 Manager d'une pharmacie
    PHARMACIST      = "pharmacist"       # Employé d'une pharmacie

# Le PLATFORM_ADMIN a pharmacy_id = NULL (pas lié à une pharmacie)
# Il a accès à TOUT sans filtre pharmacy_id
```

### 8.3 Routes API dédiées au Platform Admin

```python
# backend/app/routes/platform_admin.py  (NOUVEAU FICHIER)

# ── Gestion des pharmacies ─────────────────────────────────────────
GET    /platform/pharmacies              # Liste toutes les pharmacies
POST   /platform/pharmacies             # Créer une nouvelle pharmacie
GET    /platform/pharmacies/{id}        # Détail d'une pharmacie
PUT    /platform/pharmacies/{id}        # Modifier une pharmacie
DELETE /platform/pharmacies/{id}        # Supprimer une pharmacie

# ── Gestion des licences ──────────────────────────────────────────
PUT    /platform/pharmacies/{id}/license  # Changer le plan (basic→pro)
POST   /platform/pharmacies/{id}/suspend  # Suspendre l'accès
POST   /platform/pharmacies/{id}/activate # Réactiver l'accès

# ── Métriques globales ────────────────────────────────────────────
GET    /platform/metrics                # Stats globales toutes pharmacies
GET    /platform/metrics/{pharma_id}    # Stats d'une pharmacie précise

# ── Support ───────────────────────────────────────────────────────
POST   /platform/pharmacies/{id}/reset-admin    # Reset mot de passe admin
POST   /platform/pharmacies/{id}/impersonate    # Se connecter en tant que
GET    /platform/audit-logs             # Logs d'activité toutes pharmacies
POST   /platform/broadcast              # Envoyer une notif à toutes les pharmacies
```

### 8.4 Sécurité — Protection stricte du rôle Platform Admin

```python
# backend/app/auth/dependencies.py — Nouveau décorateur

from functools import wraps

def require_platform_admin(current_user: User = Depends(get_current_user)):
    """
    Décorateur qui bloque l'accès si l'utilisateur n'est pas Platform Admin.
    À utiliser sur TOUTES les routes /platform/...
    """
    if current_user.role != UserRole.PLATFORM_ADMIN:
        raise HTTPException(
            status_code=403,
            detail="Accès réservé au gestionnaire de la plateforme"
        )
    return current_user

# Exemple d'utilisation dans une route
@router.get("/platform/pharmacies")
def list_all_pharmacies(
    admin: User = Depends(require_platform_admin),  # 🔒 Protection
    db: Session = Depends(get_db)
):
    return db.query(Pharmacy).all()  # Toutes les pharmacies, sans filtre
```

> [!CAUTION]
> Le mode **Impersonate** (se connecter en tant qu'une pharmacie) doit être loggé dans `audit_logs` avec l'IP, l'heure et la durée de la session. C'est critique pour la conformité et la confiance des clients.

### 8.5 Tableau de bord Platform Admin (Interface Flutter)

```
┌─────────────────────────────────────────────────────────────────────┐
│  🏥 PharmaGestion — Tableau de bord Plateforme                      │
├───────────────┬─────────────────────────────────────────────────────┤
│               │                                                     │
│  📋 MENU      │  📊 VUE GLOBALE                                     │
│               │  ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  ▶ Dashboard  │  │ 12       │ │ 87       │ │ 3        │            │
│  🏥 Pharmacies│  │ Pharmacies│ │ Utilisat.│ │ Inactives│            │
│  📜 Licences  │  └──────────┘ └──────────┘ └──────────┘            │
│  📊 Métriques │                                                     │
│  🔔 Notifs    │  📋 LISTE DES PHARMACIES                            │
│  📝 Logs      │  ┌────────────────────────────────────────────────┐ │
│  ⚙️ Paramètres│  │ Nom           │ Plan  │ Users │ Statut │ Actions│ │
│               │  │──────────────────────────────────────────────  │ │
│               │  │ Pharma Abidjan│ Pro   │ 7/10  │ ✅ Actif│ [···] │ │
│               │  │ Pharma Bouaké │ Basic │ 2/3   │ ✅ Actif│ [···] │ │
│               │  │ Pharma Yamoussa│ Pro  │ 0/10  │ ⏸ Suspendu│[···]│ │
│               │  └────────────────────────────────────────────────┘ │
│               │                                                     │
│               │  [+ Nouvelle pharmacie]  [📢 Notifier toutes]       │
└───────────────┴─────────────────────────────────────────────────────┘
```

### 8.6 Fichiers Flutter à créer pour le Platform Admin

```
frontend1/lib/screens/platform_admin/
├── platform_dashboard_page.dart      # Tableau de bord global
├── pharmacies_list_page.dart         # Liste toutes les pharmacies
├── pharmacy_detail_page.dart         # Détail + gestion d'une pharmacie
├── pharmacy_create_page.dart         # Formulaire création
├── license_management_page.dart      # Gestion des licences/plans
├── platform_metrics_page.dart        # Métriques et statistiques globales
├── audit_logs_page.dart              # Logs d'activité
└── broadcast_notification_page.dart  # Envoyer notif à toutes les pharmacies

frontend1/lib/services/
└── platform_admin_service.dart       # Appels API /platform/...
```

### 8.7 Flux de connexion selon le rôle

```
User se connecte
       │
       ▼
   Vérification du rôle dans le JWT
       │
       ├── role == "platform_admin"
       │       └──▶ Redirection vers PlatformDashboardPage
       │                (accès à toutes les pharmacies)
       │
       ├── role == "super_admin" ou "pharmacy_admin"
       │       └──▶ Redirection vers AdminDashboardPage
       │                (sa pharmacie seulement)
       │
       └── role == "pharmacist"
               └──▶ Redirection vers POSPage / DashboardPage
                        (sa pharmacie seulement, accès limité)
```

---

## 9. Différenciation des Fonctionnalités par Licence

> La logique est simple : **les fonctionnalités de base sont dans tous les plans**, les fonctionnalités avancées sont verrouillées côté backend ET côté Flutter selon le plan de la pharmacie.

---

### 9.1 Matrice complète des fonctionnalités

#### 🟢 POS & Ventes

| Fonctionnalité | Basic | Pro | Enterprise |
|---|:---:|:---:|:---:|
| Caisse POS (ventes en unités, boîtes, plaquettes) | ✅ | ✅ | ✅ |
| Historique des ventes (30 jours) | ✅ | ✅ | ✅ |
| Historique des ventes (illimité) | ❌ | ✅ | ✅ |
| Annulation de vente | ✅ | ✅ | ✅ |
| Remise sur vente (%) | ❌ | ✅ | ✅ |
| Vente avec assurance (couverture %) | ❌ | ✅ | ✅ |
| Vente par client enregistré (fidélité) | ❌ | ✅ | ✅ |
| Mode hors-ligne (SQLite local) | ✅ | ✅ | ✅ |
| Synchronisation cloud automatique | ❌ | ✅ | ✅ |
| Ticket de caisse personnalisé (logo, nom pharmacie) | ❌ | ✅ | ✅ |

#### 🟢 Stock & Médicaments

| Fonctionnalité | Basic | Pro | Enterprise |
|---|:---:|:---:|:---:|
| Gestion du stock (ajout, modification, suppression) | ✅ | ✅ | ✅ |
| Alertes stock minimum | ✅ | ✅ | ✅ |
| Alertes péremption | ✅ | ✅ | ✅ |
| Gestion des lots (numéro de lot, date péremption) | ✅ | ✅ | ✅ |
| Multi-niveaux de prix (unité, boîte, carton) | ✅ | ✅ | ✅ |
| Historique des mouvements de stock | ❌ | ✅ | ✅ |
| Inventaire / Réconciliation de stock | ❌ | ✅ | ✅ |
| Gestion par code-barres (scanner) | ❌ | ✅ | ✅ |
| Import stock en masse (CSV/Excel) | ❌ | ❌ | ✅ |
| Transfert de stock entre pharmacies (chaîne) | ❌ | ❌ | ✅ |

#### 🟢 Approvisionnement & Fournisseurs

| Fonctionnalité | Basic | Pro | Enterprise |
|---|:---:|:---:|:---:|
| Gestion des fournisseurs | ✅ | ✅ | ✅ |
| Commandes de réapprovisionnement | ✅ | ✅ | ✅ |
| Historique des commandes | ❌ | ✅ | ✅ |
| Relances fournisseurs automatiques | ❌ | ❌ | ✅ |
| Comparaison prix fournisseurs | ❌ | ❌ | ✅ |

#### 🟢 Rapports & Statistiques

| Fonctionnalité | Basic | Pro | Enterprise |
|---|:---:|:---:|:---:|
| Rapport stock (PDF) | ✅ | ✅ | ✅ |
| Rapport ventes du jour | ✅ | ✅ | ✅ |
| Rapport ventes par période | ❌ | ✅ | ✅ |
| Rapport financier (revenus, marges) | ❌ | ✅ | ✅ |
| Rapport trésorerie | ❌ | ✅ | ✅ |
| Export Excel & Word | ❌ | ✅ | ✅ |
| Rapport par utilisateur (qui a vendu quoi) | ❌ | ✅ | ✅ |
| Tableau de bord avec graphiques avancés | ❌ | ✅ | ✅ |
| Rapport multi-pharmacies (vue consolidée chaîne) | ❌ | ❌ | ✅ |
| Rapport personnalisé (requêtes sur mesure) | ❌ | ❌ | ✅ |

#### 🟢 Clients & Fidélité

| Fonctionnalité | Basic | Pro | Enterprise |
|---|:---:|:---:|:---:|
| Gestion des clients (ajout, modification) | ❌ | ✅ | ✅ |
| Historique des achats par client | ❌ | ✅ | ✅ |
| Programme de fidélité (points, réductions) | ❌ | ❌ | ✅ |
| Notifications clients (SMS/Email) | ❌ | ❌ | ✅ |

#### 🟢 Utilisateurs & Sécurité

| Fonctionnalité | Basic | Pro | Enterprise |
|---|:---:|:---:|:---:|
| Nombre max d'utilisateurs | **3** | **10** | **Illimité** |
| Rôles : Admin + Pharmacien | ✅ | ✅ | ✅ |
| Rôle Manager (gère plusieurs caisses) | ❌ | ✅ | ✅ |
| Audit log (qui a fait quoi, quand) | ❌ | ✅ | ✅ |
| Connexion par code PIN rapide | ❌ | ✅ | ✅ |
| Authentification 2 facteurs (2FA) | ❌ | ❌ | ✅ |

#### 🟢 Sync & Cloud

| Fonctionnalité | Basic | Pro | Enterprise |
|---|:---:|:---:|:---:|
| Mode hors-ligne (local SQLite) | ✅ | ✅ | ✅ |
| Sync cloud manuelle | ❌ | ✅ | ✅ |
| Sync cloud automatique en temps réel | ❌ | ✅ | ✅ |
| Sauvegarde automatique cloud | ❌ | ✅ | ✅ |
| Accès multi-postes simultanés (même pharmacie) | ❌ | ✅ | ✅ |
| Multi-pharmacies (chaîne) | ❌ | ❌ | ✅ |

#### 🟢 Support & Maintenance

| Fonctionnalité | Basic | Pro | Enterprise |
|---|:---:|:---:|:---:|
| Support par email | ✅ | ✅ | ✅ |
| Support prioritaire (réponse < 24h) | ❌ | ✅ | ✅ |
| Support téléphonique dédié | ❌ | ❌ | ✅ |
| Mises à jour automatiques | ✅ | ✅ | ✅ |
| Formation et onboarding inclus | ❌ | ✅ | ✅ |

---

### 9.2 Résumé des plans

```
┌──────────────────────────────────────────────────────────────────────┐
│  BASIC (~15 000 F CFA/mois)                                          │
│  → Pour une petite pharmacie qui démarre                             │
│  → 3 utilisateurs max                                                │
│  → POS, Stock de base, Rapport stock PDF, Mode hors-ligne            │
│  → PAS de cloud, PAS de rapports avancés, PAS de remises             │
├──────────────────────────────────────────────────────────────────────┤
│  PRO (~35 000 F CFA/mois)          ⭐ Le plus populaire              │
│  → Pour une pharmacie bien établie avec du personnel                 │
│  → 10 utilisateurs max                                               │
│  → Tout Basic + Cloud sync, Rapports complets, Clients,              │
│     Remises, Assurance, Audit log, Export Excel/Word                 │
├──────────────────────────────────────────────────────────────────────┤
│  ENTERPRISE (Sur devis — ~80 000+ F CFA/mois)                        │
│  → Pour une chaîne de pharmacies ou une grande structure             │
│  → Utilisateurs illimités                                            │
│  → Tout Pro + Multi-pharmacies, Fidélité clients, 2FA,               │
│     Import CSV, Transferts inter-pharmacies, Rapports consolidés     │
└──────────────────────────────────────────────────────────────────────┘
```

---

### 9.3 Comment implémenter le verrou de licence techniquement

#### Côté Backend (FastAPI) — Décorateur `require_plan`

```python
# backend/app/core/license_guard.py  (NOUVEAU)

from fastapi import HTTPException, Depends
from app.models.pharmacy import Pharmacy, LicensePlan
from app.auth.dependencies import get_current_pharmacy_context

PLAN_HIERARCHY = {"basic": 0, "pro": 1, "enterprise": 2}

def require_plan(minimum_plan: str):
    """
    Décorateur qui bloque l'accès si le plan de la pharmacie
    est inférieur au plan minimum requis.

    Usage :
        @router.get("/ventes/historique")
        def get_historique(
            _=Depends(require_plan("pro")),  # Bloque si Basic
            ...
        ):
    """
    def dependency(ctx = Depends(get_current_pharmacy_context)):
        if ctx.is_platform_admin:
            return  # Platform admin a toujours accès
        pharmacy_plan = ctx.pharmacy.plan  # ex: "basic"
        if PLAN_HIERARCHY.get(pharmacy_plan, 0) < PLAN_HIERARCHY[minimum_plan]:
            raise HTTPException(
                status_code=403,
                detail={
                    "error": "PLAN_UPGRADE_REQUIRED",
                    "message": f"Cette fonctionnalité nécessite le plan '{minimum_plan}' ou supérieur.",
                    "current_plan": pharmacy_plan,
                    "required_plan": minimum_plan,
                }
            )
    return Depends(dependency)
```

```python
# Exemple d'application dans les routes existantes

# reports.py — Rapport par période → Pro seulement
@router.get("/stock/pdf")
def stock_pdf_report(
    _=require_plan("basic"),      # Tout le monde
    ...
): ...

@router.get("/financial/pdf")
def financial_pdf(
    _=require_plan("pro"),        # Pro et Enterprise seulement
    ...
): ...

# pos.py — Remise → Pro seulement
@router.post("/checkout")
def checkout(
    sale: SaleCreate,
    _=require_plan("basic"),      # Vente simple : tout le monde
    ...
): ...

@router.post("/checkout-with-discount")
def checkout_with_discount(
    _=require_plan("pro"),        # Remise : Pro seulement
    ...
): ...

# users.py — Limite du nb d'utilisateurs
@router.post("/users")
def create_user(ctx = Depends(get_current_pharmacy_context), db = ...):
    max_users = {"basic": 3, "pro": 10, "enterprise": 999999}
    current_count = db.query(User).filter(User.pharmacy_id == ctx.pharmacy_id).count()
    if current_count >= max_users[ctx.pharmacy.plan]:
        raise HTTPException(403, "Limite d'utilisateurs atteinte pour votre plan")
    ...
```

#### Côté Frontend Flutter — Affichage conditionnel

```dart
// frontend1/lib/core/license_guard.dart  (NOUVEAU)

enum LicensePlan { basic, pro, enterprise }

class LicenseGuard {
  final LicensePlan currentPlan;

  LicenseGuard(this.currentPlan);

  bool canAccess(LicensePlan requiredPlan) {
    return currentPlan.index >= requiredPlan.index;
  }

  // Widget qui affiche un cadenas si la feature est verrouillée
  Widget guard({
    required LicensePlan required,
    required Widget child,
  }) {
    if (canAccess(required)) return child;

    return Stack(children: [
      Opacity(opacity: 0.4, child: child),
      Positioned.fill(
        child: InkWell(
          onTap: () => _showUpgradeDialog(),
          child: Container(
            color: Colors.black26,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, color: Colors.white, size: 32),
                SizedBox(height: 8),
                Text(
                  'Plan ${required.name.toUpperCase()} requis',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    ]);
  }

  void _showUpgradeDialog() {
    // Afficher un dialogue invitant à passer au plan supérieur
  }
}
```

```dart
// Exemple d'utilisation dans reports_page.dart

LicenseGuard guard = context.read<AuthProvider>().licenseGuard;

// Rapport stock → Basic (tous)
ElevatedButton(
  onPressed: () => downloadStockPDF(),
  child: Text('Rapport Stock PDF'),
)

// Rapport financier → Pro seulement (cadenas si Basic)
guard.guard(
  required: LicensePlan.pro,
  child: ElevatedButton(
    onPressed: () => downloadFinancialPDF(),
    child: Text('Rapport Financier PDF'),
  ),
)
```

---

### 9.4 Gestion des limites — Tableau de bord (côté pharmacie)

```
┌─────────────────────────────────────────────────────────────────┐
│  📋 Votre Plan : BASIC                        [Passer en PRO →] │
├─────────────────────────────────────────────────────────────────┤
│  👥 Utilisateurs      2 / 3     ████████░░  67%                 │
│  📅 Ventes ce mois    142                                        │
│  💾 Stockage local    SQLite (hors-ligne)                        │
│                                                                  │
│  🔒 Fonctionnalités non disponibles dans votre plan :            │
│     • Synchronisation cloud                                      │
│     • Rapport financier complet                                  │
│     • Gestion des clients                                        │
│     • Remises sur ventes                                         │
│                                     [Voir tous les avantages]   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 10. Modèle Commercial

| Plan | Users max | Pharmacies | Prix/mois |
|---|:---:|:---:|---:|
| **Basic** | 3 | 1 | ~15 000 F CFA |
| **Pro** | 10 | 1 | ~35 000 F CFA |
| **Enterprise** | Illimité | Illimité | Sur devis |
| **Chaîne** (2-5 pharmacies) | 5/pharmacie | 2-5 | ~25 000 F CFA/pharmacie |

---

## ✅ Prochaine action recommandée

**Commencer par Phase 1 — Créer le modèle `Pharmacy` et migrer les données existantes vers une "pharmacie par défaut".**

Cela ne casse rien et pose la fondation. Veux-tu qu'on commence ?
