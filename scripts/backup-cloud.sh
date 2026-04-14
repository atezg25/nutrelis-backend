#!/bin/bash
# ===========================================
# BACKUP AUTOMATIQUE NUTRELIS → Hostinger FTP
# Usage: bash scripts/backup-cloud.sh
# Cron:  0 3 * * 0 bash /home/anicet/projets/nutrelis-backend/scripts/backup-cloud.sh >> /home/anicet/nutrelis-backups/cron.log 2>&1
# ===========================================

set -e

export PATH="/usr/lib/postgresql/18/bin:$PATH"

# --- Config ---
DB_URL="postgresql://postgres:pmoEdQeGBhFNlRaFewyNGelMXiHSSaTu@maglev.proxy.rlwy.net:23301/railway"
FTP_HOST="ftp.atz.septentrionsports.org"
FTP_USER="u737268845.nutrelis"
FTP_PASS="Papaisrael@777"
FTP_DIR="NUTRELIS-BACKUP"
BACKUP_DIR="$HOME/nutrelis-backups"
MAX_BACKUPS=10

# --- Backup local ---
mkdir -p "$BACKUP_DIR"
DATE=$(date +%Y-%m-%d_%H-%M)
FILENAME="nutrelis_backup_${DATE}.sql.gz"

echo "[$DATE] Sauvegarde en cours..."
pg_dump "$DB_URL" --no-owner --no-acl | gzip > "$BACKUP_DIR/$FILENAME"

SIZE=$(du -h "$BACKUP_DIR/$FILENAME" | cut -f1)
echo "[$DATE] Backup local OK : $FILENAME ($SIZE)"

# Vérifier que le fichier n'est pas vide
FILESIZE=$(stat -c%s "$BACKUP_DIR/$FILENAME")
if [ "$FILESIZE" -lt 1000 ]; then
  echo "[$DATE] ERREUR : backup trop petit ($FILESIZE octets), abandon upload"
  exit 1
fi

# --- Upload FTP Hostinger ---
echo "[$DATE] Upload vers Hostinger..."
curl -s -T "$BACKUP_DIR/$FILENAME" \
  -u "$FTP_USER:$FTP_PASS" \
  "ftp://$FTP_HOST/$FTP_DIR/$FILENAME"

echo "[$DATE] Upload OK : $FTP_DIR/$FILENAME"

# --- Nettoyage local (garder les N derniers) ---
cd "$BACKUP_DIR"
ls -t nutrelis_backup_*.sql.gz 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)) | xargs -r rm
LOCAL_COUNT=$(ls nutrelis_backup_*.sql.gz 2>/dev/null | wc -l)
echo "[$DATE] $LOCAL_COUNT backup(s) en local"

# --- Nettoyage FTP (garder les N derniers) ---
REMOTE_FILES=$(curl -s -u "$FTP_USER:$FTP_PASS" "ftp://$FTP_HOST/$FTP_DIR/" --list-only 2>/dev/null | grep "nutrelis_backup_" | sort -r)
REMOTE_COUNT=0
for FILE in $REMOTE_FILES; do
  REMOTE_COUNT=$((REMOTE_COUNT + 1))
  if [ "$REMOTE_COUNT" -gt "$MAX_BACKUPS" ]; then
    curl -s -u "$FTP_USER:$FTP_PASS" "ftp://$FTP_HOST/" -Q "DELE $FTP_DIR/$FILE" > /dev/null 2>&1
    echo "[$DATE] Supprimé ancien backup FTP : $FILE"
  fi
done

echo "[$DATE] Terminé. Backup local + Hostinger OK."
