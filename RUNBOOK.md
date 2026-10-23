# Runbook d'Exploitation & Maintenance — PharmaGest Online

Ce document regroupe les procédures opérationnelles standards pour l'infrastructure cloud, la sécurité et la maintenance de la plateforme multi-tenant PharmaGest.

---

## 1. Hébergement & Disponibilité (Render & Aiven)

### Render (API Backend)
- **Service :** `gestpharma` (Web Service, Région Frankfurt)
- **Runtime :** Python / Uvicorn (4 workers)
- **Plan recommandé :** Starter ($7/mois minimum) pour éviter la mise en veille (spin-down après 15 min d'inactivité).
- **Health Check Path :** `/health` (HTTP 200)
- **Auto-restart :** Activé par défaut.

### Aiven (MySQL Clustered Database)
- **Sauvegardes automatiques (PITR - Point-in-Time Recovery) :**
  - Rétention recommandée : 14 jours minimum.
  - Sauvegardes continues des logs binaires (WAL/binlog).
  - Vérification hebdomadaire de l'état des sauvegardes via la console Aiven.

---

## 2. Procédures Opérationnelles

### A. Rotation de la clé secrète (`SECRET_KEY`)
1. Générer une nouvelle clé aléatoire forte :
   ```bash
   python -c "import secrets; print(secrets.token_urlsafe(64))"
   ```
2. Ouvrir le Dashboard Render -> Service `gestpharma` -> **Environment**.
3. Remplacer `SECRET_KEY` par la nouvelle valeur.
4. Redémarrer le service (**Manual Deploy -> Clear build cache & deploy**).
5. *Note :* Tous les tokens JWT existants seront invalidés, obligeant les utilisateurs à se reconnecter.

### B. Restauration d'une sauvegarde de base de données (PITR)
1. Se connecter à [Aiven Console](https://console.aiven.io).
2. Sélectionner le service MySQL de production -> onglet **Backups**.
3. Choisir le point de restauration (timestamp précis ou snapshot le plus récent).
4. Créer un nouveau service ou restaurer dans une instance temporaire de vérification (recommandé pour éviter d'écraser la prod).
5. Vérifier l'intégrité des tables clés (`pharmacies`, `users`, `medicines`, `pos_sales`).
6. Mettre à jour `DB_URL_REMOTE` et `DB_URL_LOCAL` dans Render pour pointer vers la base restaurée.

### C. Déploiement d'une nouvelle version (Migrations Alembic)
1. Toujours tester les migrations d'abord sur l'environnement de staging :
   ```bash
   alembic upgrade head
   ```
2. En production, le script `render_main.py` exécute automatiquement les vérifications d'amorçage au démarrage.
3. Vérifier les logs Render pour s'assurer de l'absence d'erreurs 500 ou de deadlocks de migration.

### D. Incident de saturation de pool de connexions
- Symptôme : Erreurs `TimeoutError: QueuePool limit of size 25 overflow 25 reached`.
- Actions :
  1. Vérifier si un batch ou une requête lourde sans index s'exécute.
  2. Ajuster temporairement `DB_POOL_SIZE` et `DB_MAX_OVERFLOW` dans les variables d'environnement si nécessaire.
  3. Relancer les instances Uvicorn.

---

## 3. Checklist de vérification avant ouverture d'un nouveau tenant
1. Création de la pharmacie via le portail ou l'API platform admin (`POST /platform/pharmacies`).
2. Vérification de l'attribution d'un code unique (`CODE_PHARMA`).
3. Vérification de la création de l'administrateur initial avec mot de passe temporaire exigé au changement.
4. Vérification que les requêtes de test de cette pharmacie n'ont accès à aucune donnée des pharmacies existantes.
