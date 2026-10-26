"""
Script de migration pour la base de données de production (Aiven Cloud MySQL).
Exécute les migrations Alembic jusqu'à HEAD en garantissant la taille de version_num.
"""

import os
import sys
from alembic.config import Config
from alembic import command
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

# Charger .env
load_dotenv(".env")
remote_url = os.getenv("DB_URL_REMOTE")

if not remote_url:
    print("[ERROR] DB_URL_REMOTE introuvable dans .env")
    sys.exit(1)

print(f"[*] Connexion à la base de données Aiven Cloud MySQL...")
os.environ["PHARMAGEST_MIGRATION_DATABASE_URL"] = remote_url

try:
    engine = create_engine(remote_url)
    with engine.connect() as conn:
        print("[*] Vérification de alembic_version.version_num (VARCHAR 100)...")
        conn.execute(text("ALTER TABLE alembic_version MODIFY version_num VARCHAR(100);"))
        conn.commit()
        print("[OK] Colonne version_num prête.")

    alembic_cfg = Config("alembic.ini")
    command.upgrade(alembic_cfg, "head")
    print("[SUCCESS] Base de données de production (Aiven MySQL) migrée avec succès à HEAD !")
except Exception as e:
    print(f"[ERROR] Échec de la migration : {e}")
    sys.exit(1)
