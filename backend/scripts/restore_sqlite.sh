#!/usr/bin/env bash
# Restore SQLite DB from backup file (copy)
set -euo pipefail
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 path/to/backup.db"
  exit 2
fi
BACKUP_FILE="$1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_PATH="$ROOT_DIR/pharmacy_local.db"
if [ ! -f "$BACKUP_FILE" ]; then
  echo "Backup file not found: $BACKUP_FILE"
  exit 1
fi
cp -v "$BACKUP_FILE" "$DB_PATH"
echo "Restored DB to $DB_PATH"
