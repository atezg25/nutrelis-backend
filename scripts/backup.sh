#!/bin/bash
# ===========================================
# BACKUP BASE DE DONNÉES NUTRELIS
# Usage: bash scripts/backup.sh
# ===========================================

set -e

# Dossier de sauvegarde
BACKUP_DIR="$HOME/nutrelis-backups"
mkdir -p "$BACKUP_DIR"

# Nom du fichier avec date
DATE=$(date +%Y-%m-%d_%H-%M)
FILENAME="nutrelis_backup_${DATE}.sql.gz"

# DATABASE_URL de Railway — à coller ici ou passer en argument
DB_URL="${1:-$DATABASE_URL}"

if [ -z "$DB_URL" ]; then
  echo "❌ Erreur: DATABASE_URL manquante"
  echo ""
  echo "Usage:"
  echo "  bash scripts/backup.sh 'postgresql://user:pass@host:5432/dbname'"
  echo ""
  echo "Tu trouves l'URL dans Railway → ton service PostgreSQL → Connect → Connection URL"
  exit 1
fi

echo "📦 Sauvegarde en cours..."
pg_dump "$DB_URL" --no-owner --no-acl | gzip > "$BACKUP_DIR/$FILENAME"

SIZE=$(du -h "$BACKUP_DIR/$FILENAME" | cut -f1)
echo "✅ Sauvegarde terminée : $BACKUP_DIR/$FILENAME ($SIZE)"
echo ""

# Garder les 10 dernières sauvegardes, supprimer les plus anciennes
cd "$BACKUP_DIR"
ls -t nutrelis_backup_*.sql.gz 2>/dev/null | tail -n +11 | xargs -r rm
TOTAL=$(ls nutrelis_backup_*.sql.gz 2>/dev/null | wc -l)
echo "📂 $TOTAL sauvegarde(s) dans $BACKUP_DIR"
