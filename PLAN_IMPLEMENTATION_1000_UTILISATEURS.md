# Plan d’implémentation — PharmaGest multitenant pour 1 000 utilisateurs

## Contexte et verdict de départ

Le projet dispose déjà d’un socle multitenant : pharmacies, rattachement des données, rôle d’administrateur de plateforme, gestion des pharmacies et certains droits par forfait. L’isolation, les migrations de production et la capacité à accueillir 1 000 utilisateurs ne sont toutefois pas encore suffisamment validées pour garantir une ouverture en production.

Le fichier `nouvelles_fonctionnalites.md` contient un catalogue de propositions ; il ne constitue pas une preuve que toutes ces fonctionnalités sont livrées.

> **Ne pas ouvrir largement la plateforme avant validation des migrations, de l’isolation entre pharmacies et de la capacité mesurée sous charge.**

## Décisions de cadrage et état de la Phase 0

### Décisions confirmées

- **Charge cible : 1 000 utilisateurs simultanément connectés sur l’ensemble de la plateforme**, et non 1 000 utilisateurs simultanés par pharmacie.
- Les migrations et tests de charge seront d’abord exécutés en environnement local isolé ou en staging ; aucune migration de production n’est autorisée sans sauvegarde, essai sur copie et accord explicite.

### Décisions encore requises

Fixer avant le test de charge les objectifs de réussite : p95/p99 des temps de réponse, taux d’erreur maximal, durée de maintien des 1 000 sessions, profil des requêtes, disponibilité cible, nombre initial de pharmacies et volume moyen de données par pharmacie. Préciser aussi si le plafond Enterprise de 1 000 utilisateurs par pharmacie doit rester inchangé.

**État Phase 0 : inventaire technique réalisé et simultanéité cible confirmée ; phase non clôturée tant que les seuils de performance et les priorités métier ne sont pas approuvés.**

## Phase 0 — Cadrage et état initial

**Avancement actuel : partielle — cible simultanée définie, inventaire du dépôt effectué, objectifs chiffrés et premier lot métier encore à approuver.**

### Travaux

1. Classer les propositions de `nouvelles_fonctionnalites.md` par priorité, coût, dépendances et forfait.
2. Définir les parcours métier prioritaires et les critères d’acceptation de chacun.
3. Établir les objectifs de capacité et de disponibilité, en séparant comptes inscrits et connexions simultanées.
4. Mesurer l’état initial du backend, de la base et du frontend.
5. Inventorier les routes, modèles, traitements de fond, tâches au démarrage, caches et flux de synchronisation.

### Livrables et critère de sortie

- Matrice fonctionnalités/forfaits/priorités.
- Objectifs de performance et de capacité approuvés.
- Inventaire des parcours et des risques techniques.

Chaque fonctionnalité possède un responsable, des critères de réussite et un ordre de livraison.

### Inventaire provisoire des fonctionnalités proposées

Le catalogue `nouvelles_fonctionnalites.md` décrit des propositions. L’existence d’un champ, d’un mode de paiement ou d’un endpoint voisin ne signifie pas que le parcours fonctionnel est terminé.

| Fonction du catalogue | État observé dans le dépôt | Suite nécessaire |
|---|---|---|
| Alertes de péremption | Alertes et endpoints liés aux dates d’expiration existent déjà | Vérifier le parcours complet, le tri par urgence et les notifications attendues avant de la déclarer terminée |
| Paiement Mobile Money | `mobile_money` existe comme mode de paiement dans le modèle métier | L’intégration fournisseur, la confirmation du paiement et la gestion idempotente ne sont pas établies par ce seul enum ; cadrer puis implémenter |
| Fond de caisse et clôture journalière | Session par caissier, rapprochement, API, écran Flutter et lien UUID POS espèces implémentés; tests ciblés SQLite passants | Valider sur staging/MySQL après sauvegarde et terminer les scénarios opérationnels avant déploiement |
| SMS automatisés | Aucun service fournisseur SMS ou flux d’envoi automatisé n’a été identifié | À développer après choix fournisseur, consentement, quotas, coûts et traitement des échecs |
| Prédiction de rupture | La recherche n’a pas confirmé de module de prédiction dédié | À développer après définition de la méthode et validation de la qualité des données de vente/stock |
| Tickets thermiques | Des fonctions de PDF/impression existent pour des documents ; elles ne prouvent pas la prise en charge des imprimantes thermiques | Vérifier les appareils ciblés et développer/tester l’impression ticket POS si nécessaire |
| Crédit client | Le modèle de paiement contient une valeur `credit` et des fonctions clients existent | Vérifier dette, échéance, remboursements, limites et rapports ; ne pas assimiler la seule valeur enum à un module de crédit livré |
| Mode sombre/clair | Des palettes clair/sombre existent dans le thème Flutter | Vérifier le sélecteur, la persistance de préférence et tous les écrans |
| Recherche universelle Ctrl+K | La recherche est présente dans plusieurs écrans, notamment stock/POS ; la recherche globale et le raccourci n’ont pas été confirmés | À développer si retenu dans le lot initial |
| Notifications push, WhatsApp, marketplace, livraison et application client | Aucun flux complet correspondant n’a été confirmé | Cadrer séparément les services externes, les coûts, la sécurité et les responsabilités |

### État initial des vérifications — actualisé le 19 octobre 2026

- Suite backend complète : **192 réussis, 16 échoués** lors de la dernière exécution.
- Suite ciblée auth, pharmacie/tenants, administration plateforme et synchronisation : **72 réussis**.
- Tests sécurité : **27 réussis**.
- Analyse Flutter : **58 diagnostics** lors du dernier contrôle ; un test widget échoue sur une attente de texte obsolète.
- Capacité de 1 000 connexions simultanées, migrations MySQL de production et déploiement : **non démontrés / non exécutés**.

### Critères nécessaires pour clôturer la Phase 0

1. Approuver des seuils mesurables p95/p99, erreurs, durée et profil de charge pour les 1 000 sessions simultanées.
2. Confirmer le plafond d’utilisateurs du forfait Enterprise et le nombre de pharmacies attendu.
3. Choisir le premier lot métier à livrer et son ordre. Le catalogue propose notamment SMS, crédit client et gestion de caisse, mais le choix n’est pas encore confirmé.
4. Attribuer à chaque fonctionnalité retenue ses critères d’acceptation backend, frontend et tenant.

## Phase 1 — Sécurité et configuration de production

### Travaux

- Remplacer toute clé secrète documentée ou exposée si elle a été utilisée et la conserver uniquement dans le gestionnaire de secrets de l’hébergeur.
- Vérifier que les comptes et mots de passe d’initialisation par défaut ne sont pas actifs en production ; imposer le changement des identifiants initiaux.
- Restreindre CORS aux domaines effectivement utilisés par le frontend.
- Revoir la protection contre les tentatives répétées, les règles de mot de passe, l’expiration et la révocation des sessions.
- Vérifier la séparation entre administrateur plateforme et rôles propres à une pharmacie.
- Ne pas renvoyer les détails d’exceptions internes, de SQL ou de configuration dans les réponses publiques.
- Éviter de consigner dans les journaux des secrets ou des données personnelles/médicales inutiles.

### Critère de sortie

Configuration de production vérifiée, secrets remplacés lorsque nécessaire, rôles testés et procédure de changement des identifiants documentée.

## Phase 2 — Migrations et bases de données

**Avancement au 19 octobre 2026 : migrations testées sur une copie MariaDB XAMPP restaurée depuis sauvegarde, puis appliquées à la base XAMPP locale `pharma_db`. Les deux bases sont à `20261001_scope_business_tables`. La production n’a pas été migrée dans cette étape.**

La sauvegarde locale, conservée hors dépôt dans `%LOCALAPPDATA%\PharmaGest\backups\pharma_db_xampp_20261019_211659.sql`, fait 38 240 octets et a été vérifiée par SHA-256 (`35fead5c08a8aae7e1d689238e934e4c5c98a2728635329d806c2bd670edee35`). La copie restaurée s’appelle `pharmagest_staging` sur le MariaDB XAMPP local.

Le sélecteur Alembic a été modifié pour exiger `PHARMAGEST_MIGRATION_DATABASE_URL` et ne plus sélectionner `DB_URL_REMOTE` implicitement. Un lancement sans cette variable échoue avant connexion.

**Validations effectuées :** chaîne complète jusqu’à `head` sur staging puis XAMPP local; seconde exécution sans nouvelle révision; comparaison des nombres d’enregistrements contrôlés entre sauvegarde/staging/local; présence de `LEGACY-DEFAULT`; colonnes tenant et absence de `pharmacy_id` NULL dans les tables vérifiées; clés uniques tenant vérifiées sur staging.

**Incident à suivre :** une commande Alembic antérieure a probablement atteint la base Aiven. Une vérification en lecture seule a observé cette base à `20261001_scope_business_tables`. Aucune commande de migration ou d’écriture cloud n’a été exécutée pendant la migration XAMPP décrite ci-dessus. Faire vérifier la sauvegarde et l’historique cloud avant toute intervention future.

### Travaux

1. Effectuer une sauvegarde de la base distante et relever sa révision Alembic réelle.
2. Tester la chaîne complète de migrations sur des copies représentatives de SQLite et MySQL/MariaDB.
3. Vérifier que les anciennes données sont correctement rattachées à `LEGACY-DEFAULT`.
4. Tester les cas de données manquantes, valeurs nulles, contraintes de clés étrangères et valeurs uniques identiques dans des pharmacies différentes.
5. Séparer les migrations Alembic versionnées de l’initialisation au démarrage. `create_all` ou une réparation automatique ne doivent pas masquer une migration manquante ni créer un schéma divergent.
6. Préparer un déploiement et un retour arrière reposant sur une sauvegarde vérifiée ; ne pas supposer qu’un downgrade restaure les données.

### Travaux restants / critère de sortie

- Rejouer et vérifier les migrations sur une copie SQLite représentative.
- Vérifier intégralement les clés étrangères, index, contraintes uniques, volumes et relations parent-enfant sur XAMPP et staging, et comparer les données avant/après au-delà des seuls totaux contrôlés.
- Décider et tester le processus de déploiement final, avec sauvegarde restaurable et procédure de reprise.
- Garder toute migration Aiven/production suspendue jusqu’à validation complète, confirmation de l’état cloud et autorisation explicite au moment du déploiement final.

La Phase 2 n’est donc **pas encore entièrement clôturée**, même si la chaîne MariaDB a été appliquée et vérifiée sur l’environnement local et sa copie staging.

## Phase 3 — Validation de l’isolation multitenant

**Avancement au 20 octobre 2026 : tests ciblés SQLite réussis pour plusieurs parcours tenant et reprise de synchronisation; phase NON clôturée. L’audit a confirmé un risque bloquant dans l’initialisation de base, la couverture route-par-route reste à terminer et la validation MariaDB/staging n’est pas faite.**

### Contrôles ajoutés pendant cette phase

- Les anciens endpoints `/auth/users` et `/auth/users/{id}` (mot de passe, statut, suppression et statistiques) sont testés contre un utilisateur d’une autre pharmacie.
- Les paramètres pharmacie sont testés en lecture et mise à jour avec deux tenants.
- Les routes par ID de médicaments et ventes (lecture, modification, suppression, facture et annulation) sont testées contre des données étrangères ; l’annulation ne modifie pas la vente ni le stock étranger.
- Les réapprovisionnements refusent un fournisseur ou médicament d’une autre pharmacie.
- La réinitialisation en masse `/admin/reset` est testée pour confirmer qu’elle ne supprime que les données de la pharmacie courante.

Les six scénarios d’isolation ajoutés aux tests (`customers`, anciens endpoints utilisateurs, paramètres, stock/ventes par ID, références de réapprovisionnement et reset) passent sous SQLite en mémoire. La suite backend complète après ces ajouts : **204 réussis, 16 échoués**; les 16 échecs sont dans les anciens tests pricing, routes POS/dashboard/users et fixtures. Les tests ciblés auth/tenant/platform/sync précédents passent également (72 tests avant les nouveaux cas).

### Constats d’audit à traiter/valider ensuite

- **Blocage confirmé — écritures d’initialisation hors contexte tenant :** `render_main.py` appelle `init_local_db()` au démarrage. `backend/app/database/core.py` utilise, entre autres, du SQL textuel `UPDATE ... WHERE pharmacy_id IS NULL` et des opérations de migration/réconciliation avec une `Session` sans `pharmacy_scope_enabled`. L’inspection locale (sans connexion DB) a confirmé que les deux fichiers `.env` non suivis par Git configurent `DB_URL_LOCAL` et `DB_URL_REMOTE` vers le même hôte Aiven. Le code ne doit donc pas être démarré avec ces fichiers chargés pendant l’audit. Un changement limité empêche maintenant `DATABASE_URL_LOCAL` de retomber sur `DB_URL_REMOTE`/`DB_URL`/`DATABASE_URL` lorsque `DB_URL_LOCAL` est absent; ce changement n’a pas été exécuté contre une base configurée. **Il ne neutralise pas encore** `init_local_db()`, `_auto_repair_schema()` ni `init_remote_db()`. Ne pas démarrer l’application ou lancer une migration contre une base partagée avant d’avoir séparé migrations versionnées et bootstrap, audité une copie isolée et approuvé une procédure de reprise.
- Inventaire statique effectué : 122 déclarations de routes réparties sur 19 modules; les routes ordinaires ont des dépendances d’authentification identifiées, tandis que `/auth/login` est public par conception et `/maintenance/status` est public à confirmer comme décision produit. Cet inventaire n’est pas encore un audit des requêtes et effets de chaque route.
- La suite ciblée auth/users/platform/sync/security/caisse a donné **115 réussis et 5 échoués** sur 120 tests; le `conftest.py` impose `DB_URL_LOCAL=sqlite:///:memory:` et vide `DB_URL_REMOTE` avant l’import de l’application. Les échecs observés concernent les attentes historiques des endpoints `/users` et des valeurs de rôles dans `test_users.py`; ils doivent être triés/corrigés avant de considérer la suite d’isolation validée. Après confirmation que les fichiers `.env` pointent vers le même hôte Aiven, aucun autre test, import applicatif, démarrage, `alembic` ou accès DB n’a été lancé dans cette reprise.
- Plusieurs routes reposent sur les hooks globaux SQLAlchemy plutôt que de passer explicitement `PharmacyContext`; vérifier chaque endpoint et chaque requête de rapport sous deux pharmacies.
- Vérifier tous les traitements de fond et tâches de démarrage dans un contexte de pharmacie explicite.
- La synchronisation contient une lecture SQL directe de la pharmacie distante ; poursuivre les tests d’isolation avec données réalistes et IDs locaux/distants différents.
- Aucun test MySQL complet de la matrice inter-tenant n’a encore été exécuté. Les tests actuels SQLite ne constituent pas une validation de production.

**Critère de sortie restant :** rendre migrations et bootstrap explicitement sûrs pour les tenants et faire supprimer/réviser les deux `.env` dont les cibles locales et distantes sont identiques; terminer l’audit route-par-route et les tests d’absence d’accès croisé pour objets, rapports, exports et flux asynchrones; trier les échecs de suite; puis répéter la matrice sur une copie MariaDB/XAMPP et sur staging après sauvegarde et autorisation. Tant que ces étapes ne sont pas réalisées, la Phase 3 ne peut pas être déclarée terminée et la phase suivante ne doit pas commencer.

### Travaux

Créer des tests d’intégration avec au moins deux pharmacies, des utilisateurs distincts et des données comparables. Tester les lectures, créations, mises à jour et suppressions pour :

- utilisateurs, médicaments, familles, types et fournisseurs ;
- clients, ventes, lignes de vente, lots et mouvements de stock ;
- réapprovisionnements, paramètres et journaux d’audit ;
- recherche, pagination, dashboard, rapports et exports ;
- synchronisation locale/Cloud, reconnexion, reprises et conflits ;
- accès direct aux enregistrements par identifiant ;
- relations entre objets (vente, ligne, médicament, lot, client, utilisateur) ;
- identifiant `pharmacy_id` transmis par le client, qui ne doit jamais accorder de droits ;
- endpoints et opérations réservés à l’administrateur plateforme.

Inventorier les requêtes SQL directes, les traitements de fond et les tâches au démarrage qui pourraient contourner les filtres ORM. Tester également les contraintes et index sur MySQL/MariaDB.

### Critère de sortie

Les tests inter-tenant passent pour chaque famille de données et chaque catégorie d’opération. Une pharmacie ne peut ni lire ni modifier les données d’une autre et les réponses ne divulguent pas l’existence de ses enregistrements.

## Phase 4 — Capacité démontrée pour 1 000 utilisateurs

**Avancement au 20 octobre 2026 : préparation locale du harnais seulement. La Phase 3 n’étant pas clôturée, la Phase 4 reste suspendue pour toute charge réseau ou conclusion de capacité; aucun test de charge réel n’a été lancé.**

Le script `backend/scripts/load_test.py` utilise uniquement la bibliothèque standard. Par défaut il est en dry-run; toute exécution réelle exige `--execute`, `PHARMAGEST_STAGING_URL`, une correspondance exacte dans `PHARMAGEST_LOADTEST_ALLOWED_HOSTS` et un CSV d’identifiants dédiés. Il refuse les URL HTTP et les hôtes Render/Aiven connus. Les comptes et mots de passe ne doivent pas être stockés dans Git.

**État des validations :** le harnais mesure latence moyenne, p50/p95/p99, débit, statuts HTTP et erreurs. Dans la reprise du 20 octobre, l’exécution isolée de `tests/test_load_test.py` n’a pas fourni de résultat observable; elle n’est donc pas comptée comme réussie. Aucun dry-run ou trafic réseau n’a été lancé pendant cette reprise. Le résultat historique de 9 tests et le dry-run sans requêtes réseau restent des validations antérieures, pas une validation nouvelle.

**Avant un vrai run :** clôturer la Phase 3; faire vérifier/corriger les deux fichiers `.env` locaux dont `DB_URL_LOCAL` et `DB_URL_REMOTE` visent le même hôte Aiven; fournir un hostname staging dédié, des comptes jetables correspondant au nombre de sessions visé, définir p95/p99/taux d’erreur/durée acceptables et confirmer les limites de connexions DB de l’environnement de staging. Aucune URL de production ni base XAMPP locale ne doit être utilisée comme cible de charge.

### Travaux

1. Définir les scénarios représentatifs : connexion, recherche, consultation et modification du stock, ventes POS, rapports et synchronisation.
2. Tester séparément la charge de 1 000 comptes et plusieurs niveaux de connexions simultanées, selon l’objectif établi en Phase 0.
3. Mesurer latence, taux d’erreur, CPU, mémoire, connexions DB, requêtes lentes et comportement des synchronisations concurrentes.
4. Dimensionner les processus backend et leurs pools de connexions par rapport aux limites réelles de l’hébergeur et de la base.
5. Examiner les endpoints coûteux ou non paginés et ajouter pagination et filtres lorsque nécessaire.
6. Tester les ralentissements et interruptions de la base, les reprises et les délais d’expiration.
7. Mettre en place alertes et tableaux de bord opérationnels.

La configuration actuelle du pool MySQL (5 connexions et jusqu’à 10 supplémentaires par processus) ne suffit pas, à elle seule, à établir une capacité. Le total dépend notamment du nombre de processus et de la limite de connexions du fournisseur de base de données.

### Recommandation sécurité — chiffrement de la base SQLite locale

**État : cadrage seulement; aucune base ni dépendance modifiée.**

#### Périmètre réellement observé

- La base SQLite est ouverte par le **backend Python/SQLAlchemy** (`backend/app/database/core.py`). En mode exécutable Windows, le chemin de données est `%APPDATA%\PharmaGestion\pharmacy_local.db`; le backend active WAL.
- Le client Flutter n’utilise actuellement pas SQLite (`sqflite`, Drift ou équivalent non repéré). Il utilise `SharedPreferences` pour des préférences et `FlutterSecureStorage` pour le jeton d’authentification. Si le besoin concerne une base embarquée directement dans l’application mobile, cette architecture n’existe pas encore et devra être cadrée séparément.

#### Option recommandée à évaluer

Évaluer **SQLCipher Community Edition** pour chiffrer le fichier SQLite local au niveau de la base, en gardant SQLAlchemy et le moteur MySQL/MariaDB inchangés. SQLAlchemy documente un dialecte `pysqlcipher` et précise qu’en Python 3 il tente `sqlcipher3`; les anciens pilotes `pysqlcipher3` et `pysqlcipher` sont signalés comme non maintenus. Le pilote SQLCipher et ses bibliothèques natives doivent être épinglés et validés sur les versions Python 3.10, Windows/PyInstaller et Linux réellement distribuées avant de retenir cette option. Le projet SQLCipher Community Edition impose également de reproduire les mentions de licence requises dans les matériaux accessibles aux utilisateurs.

Alternative commerciale : **SQLite SEE** chiffre également le fichier et ses métadonnées, mais nécessite une licence payante et la compilation/intégration de la bibliothèque native. Comparer cette option si le support fournisseur ou les exigences contractuelles justifient son coût. Ne pas confondre le chiffrement du disque (BitLocker) ou les ACL Windows avec le chiffrement applicatif du fichier : ils restent des défenses complémentaires, pas le remplacement d’un chiffrement SQLite lorsqu’un fichier de sauvegarde ou de données est copié hors de la machine.

#### Gestion de la clé — condition préalable à tout chiffrement

1. Générer une clé aléatoire à forte entropie avec un générateur cryptographiquement sûr; ne jamais dériver une clé d’un nom de pharmacie, d’un mot de passe faible, d’un UUID public ou d’une valeur intégrée au code.
2. Sous Windows, protéger la clé avec **DPAPI au scope utilisateur** (sans `CRYPTPROTECT_LOCAL_MACHINE`) et les ACL du répertoire de données. DPAPI utilisateur lie normalement le déchiffrement au même compte Windows et à la même machine; un changement/réinitialisation administrative de profil ou de mot de passe peut compromettre la récupération. Concevoir une procédure de récupération/rotation avant d’activer le chiffrement.
3. Ne jamais placer la clé en clair dans le dépôt, l’exécutable, `.env`, une variable de configuration, l’URL SQLAlchemy, les journaux, ou à côté de la base en clair. Une clé incorporée dans une application distribuée est extractible : aucun mécanisme local ne peut garantir l’accès exclusif au binaire face à un administrateur ou à un attaquant contrôlant le compte/la machine. Le modèle protège surtout contre la copie hors ligne du fichier; il ne protège pas les données lorsque le backend est compromis et les a déchiffrées en mémoire.
4. Conserver un flux d’ouverture qui échoue de façon sûre si le pilote ou la clé manque; ne jamais retomber silencieusement sur SQLite en clair. Documenter la sauvegarde chiffrée, l’accès de récupération à la clé, la révocation/rotation et la perte définitive de données si la clé est perdue.

#### Migration et validation exigées avant adoption

- Ne pas convertir automatiquement la base utilisateur au démarrage. Le passage du SQLite actuel en clair vers SQLCipher requiert une copie/export vers un nouveau fichier chiffré; l’opération doit se faire sur une sauvegarde, être atomique autant que possible et inclure vérification de schéma, intégrité (`integrity_check`), comptages, relations et lecture/écriture avec la clé finale.
- Fermer toutes les connexions avant copie et traiter explicitement les fichiers WAL/SHM et toute sauvegarde temporaire en clair. Ne supprimer l’original qu’après vérification, selon une procédure documentée et testée; le « secure delete » n’est pas une garantie d’effacement sur SSD ou sauvegardes.
- Tester d’abord sur une copie isolée de `pharmacy_local.db` : installation et démarrage propre, ouverture d’une base chiffrée, refus d’une mauvaise clé, migration Alembic, création/restauration de sauvegarde, récupération après interruption, sync offline/online et performances POS. Tester chaque cible d’OS/architecture et l’empaquetage de ses bibliothèques natives.
- Garder le moteur MySQL/MariaDB séparé : SQLCipher ne chiffre que les fichiers SQLite; la sécurité du transport, les sauvegardes et le chiffrement au repos des bases distantes relèvent de contrôles distincts.

**Décision proposée :** faire un prototype SQLCipher isolé sur copie, avec pilote `sqlcipher3` explicitement sélectionné et clé DPAPI utilisateur, puis comparer compatibilité de packaging, reprise des sauvegardes, latence de démarrage et parcours de synchronisation. Ne pas démarrer l’implémentation ni convertir les données avant approbation de cette matrice et d’une procédure de récupération testée.

### Critère de sortie

Rapport de test de charge avec simultanéité testée, objectifs et résultats, limites observées, dimensionnement recommandé et marge de croissance. Ne pas annoncer « 1 000 utilisateurs simultanés » sans résultats correspondants.

## Phase 5 — Préparer l’application à la montée en charge

**Avancement au 19 octobre 2026 : premier goulot corrigé — liste des pharmacies plateforme paginée/recherchable côté API et Flutter. La préparation globale à la charge reste en cours.**

**Mise à jour caisse :** le module par caissier est relié au checkout espèces et à l’ordre de synchronisation hors ligne; ce changement ne constitue pas un test de capacité ni une validation MySQL.

`GET /platform/pharmacies` accepte maintenant `page`, `page_size` (maximum 100) et `search`, et renvoie les métadonnées de pagination. Flutter ne charge que 25 pharmacies par page, délègue la recherche au serveur avec debounce et ne recharge plus les métriques globales à chaque navigation de page. Les tests backend de pagination/recherche et le test Flutter du modèle paginé passent.

**Reste à mesurer avant de dimensionner :** index des requêtes chaudes, limites de résultats POS, endpoints de rapports qui matérialisent de grands historiques, caches locaux par processus, connexions pool×workers, journaux et tâches de démarrage. Ne pas augmenter les pools ni ajouter des workers sans connaître les limites MySQL du staging et les résultats du test de charge Phase 4.

### Travaux

- Ajouter pagination et filtres aux listes qui peuvent croître (pharmacies, utilisateurs, historique et données métier).
- Ajouter des index SQL selon les requêtes et mesures observées : `pharmacy_id`, dates, statuts et clés de relations.
- Vérifier que les caches sont isolés par pharmacie, bornés en mémoire et expirent correctement.
- Déplacer les traitements longs (exports, envois, analyses coûteuses) hors du chemin synchrone des requêtes utilisateur lorsque les tests le justifient.
- Si nécessaire, introduire une file de tâches et des workers avec reprises idempotentes.
- Documenter sauvegarde/restauration, surveillance, déploiement et réponse aux incidents.

### Critère de sortie

Les parcours prioritaires respectent les seuils de performance retenus et les tâches longues ne dégradent pas le POS.

## Phase 6 — Livraison des fonctionnalités métier prioritaires

Livrer chaque fonctionnalité de bout en bout (API, interface Flutter, autorisations côté serveur, droits du forfait et tests d’isolation).

### Lot A — Opérations quotidiennes

1. Alertes de médicaments proches de la péremption.
2. Impression de tickets thermiques sur les appareils pris en charge.
3. Gestion du fond de caisse et clôture journalière (**implémentée et testée sur SQLite ciblé; validation staging et déploiement restent à faire**).
4. Recherche globale dans les médicaments, clients, ventes et fournisseurs.
5. Mode sombre et finalisation des langues prioritaires.

### Lot B — Stock et vente

1. Suggestions de réapprovisionnement à partir des ventes et du stock.
2. Prévision des ruptures : débuter avec une méthode explicable, puis mesurer sa pertinence.
3. Crédit client avec historique, remboursements, limites et autorisations.
4. Multi-caisse avec prévention des conflits de stock lors de ventes simultanées.
5. Gestion des ordonnances après définition des besoins réglementaires et opérationnels.

### Lot C — Comptabilité et fidélité

1. Comptabilité simplifiée, exports et rapprochements.
2. Suggestions de ventes complémentaires si les données sont suffisantes et leur usage validé.
3. Analyse saisonnière lorsque la qualité et la durée de l’historique le permettent.
4. Fidélité avec règles et limites clairement associées au forfait.

### Critère de sortie de chaque fonctionnalité

Parcours frontend/API testé, autorisations imposées côté backend, règles de forfait vérifiées, données tenant-scoped et tests automatisés réussis.

## Hors périmètre actuel — intégrations avancées (phase reportée)

Conformément à la décision produit, les intégrations avancées ne font pas partie des phases à exécuter actuellement. Elles restent documentées comme pistes futures, mais ne bloquent pas la mise en œuvre des phases retenues :

- paiements Mobile Money avec confirmation par un fournisseur ;
- SMS automatisés, notifications push et WhatsApp Business ;
- livraison à domicile ;
- application destinée aux clients ;
- marketplace fournisseurs ;
- vérification des interactions médicamenteuses ;
- mode kiosque.

Les fonctionnalités métier des Phases 0 à 6 peuvent être poursuivies sans développer ces intégrations. Si l’une d’elles devient prioritaire, elle sera cadrée et planifiée séparément, avec ses exigences de sécurité, coûts, consentement, disponibilité et idempotence.

## Phase 7 — Déploiement progressif

1. Déployer auprès d’une pharmacie pilote après sauvegarde et validation des migrations.
2. Contrôler authentification, POS, stock, rapports, autorisations et synchronisation.
3. Élargir à un petit groupe de pharmacies.
4. Suivre performances, erreurs, synchronisation et éventuels incidents d’isolation.
5. Augmenter progressivement la charge et le nombre de pharmacies uniquement lorsque les critères de sortie sont satisfaits.
6. Vérifier qu’une pharmacie peut être suspendue sans interrompre les autres tenants.

### Critère de sortie

Les migrations, tests d’isolation, procédures de restauration et objectifs de charge sont validés avant l’ouverture générale.

## Priorités d’exécution

| Priorité | Action | Condition de réussite |
|---|---|---|
| P0 | Sécuriser les secrets et vérifier la base distante | Configuration de production et état Alembic contrôlés ; migrations validées sur copie |
| P1 | Terminer les tests d’isolation | Aucun accès croisé pour les routes, rapports, relations, synchronisation et accès par ID |
| P2 | Mesurer la capacité | Test de charge correspondant à la simultanéité visée et résultats documentés |
| P3 | Stabiliser les suites de tests | Résultats backend et Flutter compris ; tests pertinents au vert |
| P4 | Livrer les fonctions métier par lots | API, UI, droits et isolation testés pour chaque fonction |
| P5 | Déployer progressivement | Pilote suivi, sauvegarde/restauration et seuils d’extension vérifiés |

## État des validations — actualisé le 19 octobre 2026

### Derniers contrôles effectués

- Suite backend complète : **192 réussis, 16 échoués** sur 208 tests.
- Suite ciblée authentification, tenants, administration plateforme et synchronisation : **72 réussis**.
- Tests de sécurité : **27 réussis**.
- Analyse Flutter : **58 diagnostics** lors du dernier contrôle.
- Tests Flutter : les tests de navigation plateforme passent ; un test de widget échoue sur une attente de texte obsolète.
- Tests de charge à 1 000 sessions, migrations MySQL de production et déploiement : **non exécutés / non démontrés**.

### Bilan historique de l’audit initial

L’audit de départ avait observé 191 tests backend réussis, 16 échoués, 9 tests ciblés plateforme/synchronisation réussis, et 2 tests de navigation Flutter réussis. Ces valeurs sont historiques et remplacées par les résultats ci-dessus lorsqu’ils sont plus récents.

Ces tests ne constituent pas une certification de préparation à la production ou de capacité à 1 000 utilisateurs simultanés. La phase d’intégrations avancées est reportée et ne fait pas partie du périmètre actuel.