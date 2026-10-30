# Plan — Refonte Navigation Admin Plateforme (v2)

> Mis à jour le 29/10/2026 — Réponses aux questions de validation intégrées.

---

## État actuel (AVANT)

```
Sidebar platform_admin:
  ├── 🏢 Plateforme       → /platform-admin   (3 onglets internes)
  ├── 📊 Analyse          → /analyse
  └── 🔑 Licence          → /license
```

---

## Cible (APRÈS)

```
Sidebar platform_admin:
  ├── 🏥 Gestion Pharmacies    → /platform/pharmacies
  ├── 🔑 Gestion Licences      → /platform/licences
  ├── 👤 Admins Plateforme     → /platform/admins
  ├── 📊 Analyse               → /analyse   (inchangé)
  └── 🏷️ Ma Licence            → /license   (inchangé)
```

> L'ancienne page `/platform-admin` (avec onglets) devient obsolète mais reste dans le code.

---

## Fichiers à créer

| Fichier | Rôle |
|---------|------|
| `lib/screens/platform/pharmacies_page.dart` | Gestion complète des pharmacies |
| `lib/screens/platform/licences_page.dart` | Gestion complète des licences |
| `lib/screens/platform/platform_admins_page.dart` | Gestion des admins plateforme (wrapper de `PlatformAdminsTab`) |

---

## Fichiers à modifier

| Fichier | Changement |
|---------|-----------|
| `lib/models/navigation_item.dart` | Remplacer l'item unique `platformAdmin` par 3 items dédiés |
| `lib/main.dart` | Ajouter 3 nouvelles routes |
| `backend/app/routes/platform_admin.py` | Exposer `license_expires_at` + ajouter endpoint config OBR |

---

## Détail — Page 1 : Gestion des Pharmacies (`/platform/pharmacies`)

### Header
- Titre "Gestion des Pharmacies"
- Bouton `+ Nouvelle Pharmacie` → dialog de création (formulaire existant)
- Bouton Actualiser + barre de recherche

### Cartes stats (2 seulement)
- Total Pharmacies | Pharmacies Actives

### Table principale

| Colonne | Détail |
|---------|--------|
| Nom | Nom complet de la pharmacie |
| Code | Code unique |
| Ville / Pays | Localisation |
| Plan | Badge (BASIC / PRO / ENTERPRISE) |
| Max Users | Nombre d'utilisateurs autorisés |
| Statut | Switch actif/inactif |
| OBR | Bouton ⚙️ "Configurer OBR" |
| Actions | Bouton ✏️ Modifier |

### Dialog Config OBR
Ouvre un formulaire **qui écrit en base de données** via `PUT /platform/pharmacies/{id}/obr-config`.

Champs du formulaire :
- **NIF** (Numéro d'Identification Fiscale)
- **RC** (Registre du Commerce)
- **Code contribuable OBR**
- **Adresse fiscale**
- **Représentant légal**
- **Téléphone fiscal**

> Ces champs seront stockés dans la table `pharmacies` (colonnes à ajouter si inexistantes).

---

## Détail — Page 2 : Gestion des Licences (`/platform/licences`)

### Section A — Vue d'ensemble des pharmacies (tableau supérieur)

**Toutes les pharmacies** sont affichées, qu'elles aient une clé ou non.

| Colonne | Détail |
|---------|--------|
| Pharmacie | Nom + code |
| Plan actuel | Badge plan |
| Licence expire le | Date `license_expires_at` ou "Aucune" |
| Jours restants | Calculé côté frontend (date - aujourd'hui) + badge couleur |
| Statut licence | ✅ Valide / ⚠️ Expire bientôt (<30j) / ❌ Expirée / — Aucune |
| Action | Bouton 🔑 "Générer une clé" (pré-sélectionne cette pharmacie dans le dialog) |

### Section B — Toutes les clés générées (tableau inférieur)

**Toutes les clés** sont affichées avec la pharmacie associée (si assignée).

| Colonne | Détail |
|---------|--------|
| Clé | Texte copiable |
| Plan | Badge |
| Durée | X jours |
| Max Users | Nombre |
| Pharmacie assignée | Nom de la pharmacie (si la clé est activée ou pré-assignée) ou "— Générique" |
| Statut | 🟢 Disponible / 🔵 Activée / ⛔ Révoquée |
| Générée le | Date |
| Actions | Copier / Révoquer (si disponible) |

**Filtres disponibles :**
- Par statut (Disponible / Activée / Révoquée / Tous)
- Par pharmacie (dropdown)

### Dialog Génération de clé
- Dropdown pharmacie (pré-rempli si venu du bouton d'une pharmacie)
- Plan (Basic / Pro / Enterprise)
- Durée (30j / 90j / 180j / 365j)
- Max utilisateurs
- Quantité (1 à 20)
- Notes optionnelles
- Récapitulatif avant confirmation

---

## Détail — Page 3 : Admins Plateforme (`/platform/admins`)

Wrapper simple autour du `PlatformAdminsTab` existant :
- Liste des admins plateforme
- Créer / Modifier / Réinitialiser mot de passe

---

## Endpoints backend

### Déjà existants ✅
| Endpoint | Usage |
|----------|-------|
| `GET /platform/pharmacies` | Liste paginée (ajouter `license_expires_at` dans la réponse) |
| `POST /platform/pharmacies` | Créer pharmacie |
| `PUT /platform/pharmacies/{id}` | Modifier pharmacie |
| `PATCH /platform/pharmacies/{id}/status` | Activer/désactiver |
| `GET /platform/admins` | Liste admins |
| `POST /license/platform/generate` | Générer clés (accepte déjà `pharmacy_id`) |
| `GET /license/platform/keys` | Liste clés |
| `PUT /license/platform/keys/{id}/revoke` | Révoquer |

### À créer 🆕
| Endpoint | Usage |
|----------|-------|
| `PUT /platform/pharmacies/{id}/obr-config` | Sauvegarder config OBR en DB |
| `GET /platform/pharmacies/{id}/obr-config` | Lire config OBR d'une pharmacie |

### À modifier 🔧
| Endpoint | Changement |
|----------|-----------|
| `GET /platform/pharmacies` | Inclure `license_expires_at`, `nif`, `rc`, `obr_code` dans la réponse |

---

## Modèle DB — Colonnes OBR à ajouter dans `pharmacies`

```sql
ALTER TABLE pharmacies ADD COLUMN nif VARCHAR(50) NULL;
ALTER TABLE pharmacies ADD COLUMN rc VARCHAR(50) NULL;
ALTER TABLE pharmacies ADD COLUMN obr_code VARCHAR(50) NULL;
ALTER TABLE pharmacies ADD COLUMN fiscal_address TEXT NULL;
ALTER TABLE pharmacies ADD COLUMN legal_representative VARCHAR(100) NULL;
ALTER TABLE pharmacies ADD COLUMN fiscal_phone VARCHAR(30) NULL;
```

> Migration Alembic à créer si ces colonnes n'existent pas encore.

---

## Étapes d'implémentation

### Étape 1 — Backend : vérifications + OBR (45 min)
- [ ] Lire `backend/app/models/pharmacy.py` → vérifier colonnes OBR existantes
- [ ] Si colonnes OBR manquantes : créer migration Alembic
- [ ] Modifier sérialisation `GET /platform/pharmacies` → exposer `license_expires_at` + champs OBR
- [ ] Ajouter `GET /platform/pharmacies/{id}/obr-config`
- [ ] Ajouter `PUT /platform/pharmacies/{id}/obr-config`

### Étape 2 — Navigation Flutter (15 min)
- [ ] `navigation_item.dart` : remplacer `platformAdminOnly` unique par 3 items distincts
  ```dart
  // Gestion Pharmacies
  NavigationItem(name: 'platformPharmacies', route: '/platform/pharmacies',
    icon: Icons.storefront_outlined, platformAdminOnly: true)
  // Gestion Licences
  NavigationItem(name: 'platformLicences', route: '/platform/licences',
    icon: Icons.vpn_key_outlined, platformAdminOnly: true)
  // Admins Plateforme
  NavigationItem(name: 'platformAdmins', route: '/platform/admins',
    icon: Icons.manage_accounts_outlined, platformAdminOnly: true)
  ```
- [ ] `main.dart` : ajouter les 3 nouvelles routes

### Étape 3 — Page Pharmacies (60 min)
- [ ] Créer `lib/screens/platform/pharmacies_page.dart`
- [ ] Reprendre la logique de `platform_admin_page.dart` (liste, pagination, dialog create/edit)
- [ ] Ajouter bouton "⚙️ Config OBR" dans chaque ligne
- [ ] Créer le dialog de configuration OBR (formulaire + appel API)

### Étape 4 — Page Licences (60 min)
- [ ] Créer `lib/screens/platform/licences_page.dart`
- [ ] Section haute : tableau toutes pharmacies + statut licence + bouton "Générer"
- [ ] Section basse : tableau toutes les clés avec colonne pharmacie assignée
- [ ] Filtres par statut et par pharmacie
- [ ] Dialog génération (reprendre `platform_licenses_tab.dart`, pré-sélection pharmacie)

### Étape 5 — Page Admins Plateforme (20 min)
- [ ] Créer `lib/screens/platform/platform_admins_page.dart`
- [ ] Wrapper simple autour de `PlatformAdminsTab`

### Étape 6 — Build + Push (20 min)
- [ ] `flutter build web --release --base-href / --no-pub`
- [ ] `git add . && git commit -m "feat(platform): sidebar modulaire pharmacies/licences/admins"`
- [ ] `git push origin main`
- [ ] `git checkout test/multitenant-online && git merge main && git push`

---

## Estimation totale : ~3h30

| Étape | Durée |
|-------|-------|
| Backend OBR + sérialisation | 45 min |
| Navigation | 15 min |
| Page Pharmacies | 60 min |
| Page Licences | 60 min |
| Page Admins | 20 min |
| Build + Push | 20 min |
| **Total** | **~3h30** |

---

## Notes importantes

> **IMPORTANT :** Le `filterByRole` dans `navigation_item.dart` doit être mis à jour :
> supprimer l'ancien item `platformAdminOnly` (route `/platform-admin`) et ajouter les 3 nouveaux.

> **NOTE :** Les traductions (`language_provider.dart`) devront être complétées pour les nouvelles clés :
> `platformPharmacies`, `platformLicences`, `platformAdmins`.

> **WARNING :** Tester que `platform_admin` ne peut toujours PAS accéder aux routes admin pharmacie
> (`/users`, `/super-admin`, etc.) après la refonte.

