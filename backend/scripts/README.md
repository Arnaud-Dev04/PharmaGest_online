SQLite backup/restore scripts

- backup_sqlite.sh : Unix shell script to copy the local SQLite DB to backups/
- restore_sqlite.sh : Restore a backup file to pharmacy_local.db
- backup_sqlite.bat : Windows batch script to create a timestamped backup

Usage examples:

Linux/macOS:

```bash
# Create backup
bash backend/scripts/backup_sqlite.sh

# Restore (example)
bash backend/scripts/restore_sqlite.sh backend/backups/pharmacy_local_2026-08-13_120000.db
```

Windows (PowerShell/CMD):

```powershell
# Create backup
backend\scripts\backup_sqlite.bat

# Copy backup file manually to %CD%\\backend\\pharmacy_local.db to restore
```
