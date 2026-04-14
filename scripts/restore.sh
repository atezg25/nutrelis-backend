#!/bin/bash
# ===========================================
# RESTAURATION BASE DE DONNÉES NUTRELIS
# Usage: bash scripts/restore.sh <fichier_backup> <database_url>
# ===========================================

set -e

BACKUP_FILE="$1"
DB_URL="${2:-$DATABASE_URL}"

if [ -z "$BACKUP_FILE" ] || [ -z "$DB_URL" ]; then
  echo "❌ Erreur: paramètres manquants"
  echo ""
  echo "Usage:"
  echo "  bash scripts/restore.sh ~/nutrelis-backups/nutrelis_backup_2026-04-14_12-00.sql.gz 'postgresql://user:pass@host:5432/dbname'"
  echo ""
  echo "⚠️  ATTENTION: cette opération REMPLACE toutes les données actuelles !"
  exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
  echo "❌ Fichier non trouvé: $BACKUP_FILE"
  exit 1
fi

echo "⚠️  ATTENTION: Cette opération va REMPLACER toutes les données de la base."
echo "   Fichier : $BACKUP_FILE"
echo ""
read -p "Confirmer ? (oui/non) : " CONFIRM

if [ "$CONFIRM" != "oui" ]; then
  echo "❌ Annulé."
  exit 0
fi

echo "🔄 Restauration en cours..."
gunzip -c "$BACKUP_FILE" | psql "$DB_URL" --quiet

echo "✅ Restauration terminée !"
echo "🔄 Redémarre le backend Railway pour prendre en compte les changements."
