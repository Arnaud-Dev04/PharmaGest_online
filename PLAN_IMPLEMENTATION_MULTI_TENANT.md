# Plan d'implementation multi-tenant

## Objectif

Permettre à plusieurs pharmacies d'utiliser PharmaGestion dans une base partagée, tout en conservant le mode SQLite hors ligne et la base MySQL cloud. Le backend détermine toujours la pharmacie autorisée à partir de l'utilisateur authentifié; un identifiant transmis par le client ne suffit jamais à accorder l'accès.

## Principes

- Garder une base partagée avec `pharmacy_id`, compatible SQLite et MySQL/MariaDB.
- Distinguer l'administrateur de plateforme des rôles d'une pharmacie; ne pas réinterpréter implicitement `SUPER_ADMIN`.
- Migrer les données existantes vers une pharmacie par défaut avant d'imposer des contraintes tenant.
- Isoler les données dans toutes les requêtes, relations, caches, rapports et flux de synchronisation.
- Exécuter les migrations de production uniquement après sauvegarde et validation sur une copie.

## Phase 0 - Cadrage et inventaire

**Statut : terminée.**

- Inventorier les 17 tables et leurs relations, les routes, services, caches et fonctions de synchronisation.
- Définir les données propres à une pharmacie et les éventuelles données de plateforme partagées.
- Déterminer la portée des contraintes d'unicité : utilisateur, code médicament, code vente, téléphone client, paramètres.
- Décider de l'identifiant de connexion et du traitement des utilisateurs plateforme.

**Critère de sortie :** matrice des propriétaires de données et règles d'accès validées avant d'ajouter des contraintes tenant.

## Phase 1 - Modèle et migration du schéma

**Statut : registre et rattachement des utilisateurs implémentés; rattachement des données métier restant à faire.**

- Créer le modèle `Pharmacy`, l'enregistrer dans SQLAlchemy et initialiser une pharmacie `LEGACY-DEFAULT` de façon idempotente.
- Créer une migration Alembic compatible avec SQLite et MySQL/MariaDB.
- Ajouter `pharmacy_id` aux modèles métier concernés, y compris les entités enfants selon la matrice de Phase 0.
- Ajouter une migration progressive : colonnes nullable, création/rattachement à `LEGACY-DEFAULT`, vérification des données, puis contraintes et index.
- Adapter les contraintes d'unicité à leur portée tenant. Conserver les identifiants universels de sync globalement uniques si nécessaire.
- Prévoir les limites de migration SQLite, notamment les reconstructions de tables avec Alembic batch mode.

**Critère de sortie :** chaque enregistrement métier existant est rattaché à une pharmacie; les données et contraintes sont validées sur SQLite et MySQL.

**État du code :** le registre et le rattachement des utilisateurs sont présents. Les modèles métier ont maintenant un marqueur `pharmacy_id`; l'isolation applicative est en cours en Phase 3 et ne doit pas encore être considérée comme validée en production.

**Vérification préalable obligatoire :** une exécution précédente a utilisé la connexion MySQL configurée par `backend/.env`; les journaux ont indiqué les révisions `20260515_pos_lot_pricing` et `20261001_create_pharmacies`. Vérifier la version Alembic et la présence de `LEGACY-DEFAULT` sur cette base avant toute nouvelle migration distante. La révision `20261001_add_user_pharmacy_id` n'a pas été exécutée à distance. Ne pas tenter de rollback automatique.

## Phase 2 - Authentification et contexte pharmacie

**Statut : implémentée côté modèle et authentification; non appliquée aux routes métier.**

- Résoudre le tenant côté serveur depuis l'utilisateur authentifié; ne pas faire confiance à un `pharmacy_id` de requête ou d'en-tête.
- Ajouter une dépendance de contexte tenant et refuser les utilisateurs métier sans pharmacie affectée.
- Ajouter `PLATFORM_ADMIN` séparément et maintenir les permissions historiques pendant la transition.
- Décider si les noms d'utilisateur restent globalement uniques ou si la connexion exige aussi le code pharmacie.
- Affecter les utilisateurs existants à `LEGACY-DEFAULT`, rattacher les nouveaux comptes au tenant de leur administrateur et interdire aux admins pharmacie de créer un `PLATFORM_ADMIN`.
- Garder les routes plateforme protégées par une dépendance dédiée; aucune route métier n'utilise encore ce contexte avant la Phase 3.

**Critère de sortie :** contexte tenant résolu depuis l'utilisateur en base, séparation de rôle vérifiée et aucun utilisateur ordinaire nouvellement créé sans pharmacie.

## Phase 3 - Isolation des routes et services

**Statut : socle backend implémenté; validation globale restante avant activation multi-pharmacies.**

- Filtrer chaque lecture, écriture, suppression, recherche, rapport et statistique par pharmacie.
- Vérifier les accès par ID et les relations parent-enfant pour empêcher les références croisées.
- Inclure le tenant dans les clés de caches globaux, dont les caches POS.
- Vérifier les routes d'administration et de maintenance, y compris celles sans utilisateur courant explicite.
- Un filtre ORM de session applique le tenant aux requêtes; les nouvelles lignes héritent du tenant courant et les références entre pharmacies sont refusées.
- Les modèles métier sont marqués tenant-scoped; la migration `20261001_scope_business_tables` ajoute les colonnes, index, clés étrangères, backfill et contraintes uniques composites.
- Les caches métier et de synchronisation sont tenant-aware; les sessions distantes de sync héritent du scope local.

**Critère de sortie :** un utilisateur de A ne peut ni lire ni modifier les données de B, même en connaissant un identifiant.

**Validations actuelles :** les 29 tests d'authentification passent; les tests couvrent liste, lecture par ID, création, référence FK inter-tenant, suppression bulk et unicité par pharmacie. La migration passe sur SQLite initialisé. Le dernier run complet (avant l'ajout des deux tests tenant) comptait 147 succès et 16 échecs sur 163 tests, dont plusieurs assertions désalignées sur les noms de tables, routes ou rôles. MySQL reste à valider sur une copie isolée; ne pas appliquer les nouvelles migrations sur la base distante avant vérification/sauvegarde.

## Phase 4 - Synchronisation hors ligne

**Statut : flux de synchronisation existants adaptés au tenant; validation des cas de production restante.**

- Ajouter le tenant aux ventes et autres objets transmis entre SQLite et MySQL.
- Isoler paramètres, files, journaux et données de référence par pharmacie.
- Garantir l'idempotence par tenant et définir la résolution des conflits lors des reconnexions.
- Vérifier le scénario hors ligne, la reprise, les doublons et les erreurs réseau.
- Résoudre la pharmacie distante par son code stable; ne jamais supposer que les IDs locaux et distants correspondent.
- Mapper utilisateurs, clients, médicaments et lots des lignes POS aux IDs distants de la même pharmacie; refuser une référence manquante ou cross-tenant.
- Isoler le pull des paramètres et le cache du statut sync par pharmacie.

**Critère de sortie :** les données synchronisées restent dans leur pharmacie d'origine et les reprises sont idempotentes.

**Validations actuelles :** 3 tests sync passent sur deux bases SQLite isolées : IDs locaux/distants différents, pull Settings sans fuite entre pharmacies et push POS idempotent. Le téléchargement du catalogue médicaments n'est pas implémenté dans le gestionnaire actuel malgré son ancien commentaire; il reste à concevoir/valider avant de revendiquer une réplication complète des données de référence.

## Phase 5 - Administration plateforme et onboarding

**Statut : API et première interface Flutter implémentées; bootstrap de production à configurer explicitement.**

- Ajouter les opérations plateforme de création, consultation, activation et suspension d'une pharmacie.
- Créer le flux d'onboarding et l'affectation du premier administrateur de pharmacie.
- Ajouter les écrans Flutter et les métriques nécessaires.
- Reporter l'impersonation à une phase distincte avec journalisation, durée limitée et audit.

**Livré :** endpoints `/platform/pharmacies` (liste, détail, création avec premier admin, édition, activation/suspension) et `/platform/metrics`, protégés par `PLATFORM_ADMIN`; bootstrap optionnel via `PLATFORM_ADMIN_USERNAME` et `PLATFORM_ADMIN_PASSWORD`; écran Flutter avec recherche, indicateurs, onboarding, édition et statut. Aucun compte plateforme n'est créé par défaut. La suppression physique est volontairement remplacée par la suspension pour préserver l'historique.

**Critère de sortie :** une pharmacie peut être administrée sans accès aux données métier d'une autre.

**Impact frontend :** l'écran plateforme et l'onboarding sont présents. L'affichage détaillé des licences/limites reste prévu en Phase 6. Le `pharmacy_id` n'est jamais une autorité côté frontend : le backend le déduit de l'utilisateur authentifié.

**Validations actuelles :** 35 tests auth, plateforme et sync passent sur SQLite mémoire; `flutter analyze` ciblé sur les fichiers modifiés a signalé zéro issue. Les tests Flutter de widget n'ont pas été exécutés. Le premier compte plateforme doit être provisionné hors dépôt via variables d'environnement sécurisées.

## Phase 6 - Licences et limites

**Statut : terminée pour les fonctionnalités présentes dans le produit.**

- Plans et licences résolus dans le contexte authentifié de la pharmacie; `/license/status` exige une session et ne divulgue aucune licence pharmacie à l'administrateur plateforme.
- Une licence expirée bloque les routes métier pour tous les rôles pharmacie. Le profil reste accessible pour renouveler la licence via la route dédiée Super Admin.
- Plafonds serveur : Basic 3 utilisateurs, Pro 10, Enterprise illimité (sentinel technique 1000). Création, réactivation et modification de plan/plafond sont contrôlées côté backend; le comptage inclut uniquement les utilisateurs actifs et les créations concurrentes verrouillent la pharmacie.
- Les droits Pro/Enterprise sont appliqués côté serveur aux clients, remises et ventes assurance, rapports avancés et exports, rapports de performance, historique de stock, audit/réconciliation et synchronisation cloud. Basic est limité aux 30 derniers jours d'historique de vente, y compris les accès directs aux détails et factures.
- La fidélité et le crédit de points sont réservés à Enterprise; les points POS sont ajoutés dans la transaction de vente.
- Flutter reflète les droits : statut du plan, effectif/quota, fonctionnalités, exports/rapports conditionnels, options POS, journaux et période d'historique; le bouton de création utilisateur est désactivé au plafond.
- Les options de licence de chaque pharmacie restent des `Settings` scoped par `pharmacy_id`; aucune licence tenant n'est traitée comme licence plateforme.

**Hors périmètre livré :** plusieurs entrées de la matrice produit sont encore des propositions sans fonctionnalité/API existante (scanner code-barres, import CSV, transferts inter-pharmacies, 2FA, SMS automatiques, rapports consolidés multi-sites). Elles ne sont pas annoncées comme disponibles; leur implémentation relève d'une phase produit ultérieure.

**Validations :** 71 tests auth/licence, plateforme et sync passent; aucun diagnostic VS Code dans les fichiers Flutter modifiés. La dernière suite backend complète a 16 échecs existants hors Phase 6 (database, POS, pricing, stock et users); `flutter analyze` n'a pas été exécuté.

**Critère de sortie :** limites et droits sont appliqués par pharmacie côté serveur.

**Impact frontend prévu :** affichage du plan, des limites d'utilisateurs et des fonctionnalités disponibles; les décisions d'autorisation restent côté backend.

## Phase 7 - Déploiement progressif

- Sauvegarder la base et tester la migration sur une copie représentative.
- Déployer d'abord avec la pharmacie existante et contrôler authentification, rapports, POS et synchronisation.
- Migrer les autres pharmacies progressivement, avec surveillance et procédure de retour arrière documentée.
- Exécuter Alembic explicitement dans le processus de déploiement après validation; ne pas dépendre uniquement de `Base.metadata.create_all`.

**Critère de sortie :** les pharmacies migrées passent les tests d'isolation, de sauvegarde et de synchronisation avant généralisation.

## Tests obligatoires

- Tests négatifs inter-tenant sur les routes et les opérations par ID.
- Deux pharmacies peuvent réutiliser les valeurs déclarées uniques par tenant.
- Migration et création du schéma sur SQLite et MySQL/MariaDB.
- Tests de synchronisation hors ligne, reconnexion, idempotence et conflits.
- Vérification que les rôles plateforme ne donnent pas implicitement accès aux données métier.

## Ordre de réalisation

Terminer et valider la Phase 1 avant d'activer la Phase 2. Ne pas ouvrir l'accès à une deuxième pharmacie avant la fin des Phases 2 à 4 et des tests d'isolation correspondants.