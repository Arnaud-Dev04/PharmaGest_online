#!/usr/bin/env bash
# Backup local SQLite DB (pharmacy_local.db)
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_PATH="$ROOT_DIR/pharmacy_local.db"
BACKUP_DIR="$ROOT_DIR/backups"
mkdir -p "$BACKUP_DIR"
TIMESTAMP="$(date +%F_%H%M%S)"
if [ ! -f "$DB_PATH" ]; then
  echo "SQLite DB not found at $DB_PATH"
  exit 1
fi
cp -v "$DB_PATH" "$BACKUP_DIR/pharmacy_local_${TIMESTAMP}.db"
echo "Backup created: $BACKUP_DIR/pharmacy_local_${TIMESTAMP}.db" 
