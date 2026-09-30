"""
Migration script: Add missing columns to medicine_pricing table.
"""
import sqlite3

conn = sqlite3.connect("pharmacy_local.db")
c = conn.cursor()

alterations = [
    ("achat_boite", "ALTER TABLE medicine_pricing ADD COLUMN achat_boite FLOAT NOT NULL DEFAULT 0.0"),
    ("achat_plaquette", "ALTER TABLE medicine_pricing ADD COLUMN achat_plaquette FLOAT NOT NULL DEFAULT 0.0"),
    ("achat_comprime", "ALTER TABLE medicine_pricing ADD COLUMN achat_comprime FLOAT NOT NULL DEFAULT 0.0"),
    ("seuil_niveau", "ALTER TABLE medicine_pricing ADD COLUMN seuil_niveau VARCHAR(20) NOT NULL DEFAULT 'comprimes'"),
    ("alerte_jours", "ALTER TABLE medicine_pricing ADD COLUMN alerte_jours INTEGER DEFAULT 30"),
]

for col_name, sql in alterations:
    try:
        c.execute(sql)
        print(f"OK: {col_name} added")
    except Exception as e:
        print(f"SKIP {col_name}: {e}")

conn.commit()

# Verify
cursor = conn.execute("PRAGMA table_info(medicine_pricing)")
cols = [row[1] for row in cursor.fetchall()]
print(f"\nAll columns ({len(cols)}):")
for col in cols:
    print(f"  - {col}")

conn.close()
print("\nMigration done!")
