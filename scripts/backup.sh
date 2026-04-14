#!/bin/bash
# ===========================================
# BACKUP BASE DE DONNÉES NUTRELIS
# Usage: bash scripts/backup.sh <DATABASE_PUBLIC_URL>
# ===========================================

set -e

BACKUP_DIR="$HOME/nutrelis-backups"
mkdir -p "$BACKUP_DIR"

DATE=$(date +%Y-%m-%d_%H-%M)
FILENAME="nutrelis_backup_${DATE}.sql.gz"

DB_URL="${1:-$DATABASE_URL}"

if [ -z "$DB_URL" ]; then
  echo "❌ Erreur: DATABASE_URL manquante"
  echo ""
  echo "Usage:"
  echo "  bash scripts/backup.sh 'postgresql://user:pass@host:port/dbname'"
  exit 1
fi

# Détecter la version de pg_dump disponible
PG_DUMP="pg_dump"
# Chercher la version la plus récente installée
for v in 18 17 16 15; do
  if [ -x "/usr/lib/postgresql/$v/bin/pg_dump" ]; then
    PG_DUMP="/usr/lib/postgresql/$v/bin/pg_dump"
    break
  fi
done

PG_DUMP_VERSION=$($PG_DUMP --version 2>/dev/null | grep -oP '\d+' | head -1)

# Extraire la version du serveur
SERVER_VERSION=$(psql "$DB_URL" -t -c "SHOW server_version_num;" 2>/dev/null | tr -d ' ' | head -1)
SERVER_MAJOR=$(echo "$SERVER_VERSION" | cut -c1-2)

echo "📦 pg_dump version: $PG_DUMP_VERSION, serveur: PostgreSQL $SERVER_MAJOR"

if [ "$PG_DUMP_VERSION" -lt "$SERVER_MAJOR" ] 2>/dev/null; then
  echo "⚠️  pg_dump ($PG_DUMP_VERSION) < serveur ($SERVER_MAJOR) — utilisation de psql pour le backup"
  echo ""

  # Backup via psql — export de toutes les tables avec données
  psql "$DB_URL" -c "\copy (SELECT schemaname, tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema')) TO STDOUT" 2>/dev/null | while IFS=$'\t' read schema table; do
    echo "-- Table: $schema.$table"
  done

  # Méthode alternative : dump complet via pg_dump avec flag de compatibilité
  $PG_DUMP "$DB_URL" --no-owner --no-acl 2>/dev/null | gzip > "$BACKUP_DIR/$FILENAME" || {
    # Si pg_dump échoue, utiliser psql pour un dump basique
    echo "🔄 Fallback: export via psql..."
    (
      echo "-- NUTRELIS BACKUP $DATE"
      echo "-- Serveur PostgreSQL $SERVER_MAJOR"
      echo ""

      # Lister toutes les tables utilisateur
      TABLES=$(psql "$DB_URL" -t -c "SELECT schemaname || '.' || tablename FROM pg_tables WHERE schemaname = 'public'" 2>/dev/null | tr -d ' ')

      for TABLE in $TABLES; do
        echo "-- Données: $TABLE"
        echo "COPY $TABLE FROM stdin;"
        psql "$DB_URL" -c "\COPY $TABLE TO STDOUT" 2>/dev/null
        echo "\\."
        echo ""
      done
    ) | gzip > "$BACKUP_DIR/$FILENAME"
  }
else
  echo "📦 Sauvegarde via pg_dump..."
  $PG_DUMP "$DB_URL" --no-owner --no-acl | gzip > "$BACKUP_DIR/$FILENAME"
fi

SIZE=$(du -h "$BACKUP_DIR/$FILENAME" | cut -f1)
echo "✅ Sauvegarde terminée : $BACKUP_DIR/$FILENAME ($SIZE)"

# Garder les 10 dernières
cd "$BACKUP_DIR"
ls -t nutrelis_backup_*.sql.gz 2>/dev/null | tail -n +11 | xargs -r rm
TOTAL=$(ls nutrelis_backup_*.sql.gz 2>/dev/null | wc -l)
echo "📂 $TOTAL sauvegarde(s) dans $BACKUP_DIR"
