#!/bin/bash

DATE=$(date +%Y%m%d_%H%M)
FULL_DIR="/var/backups/mysql/full"
INCR_DIR="/var/backups/mysql/incremental"

mkdir -p "$FULL_DIR" "$INCR_DIR"

CURRENT_FULL=$(ls -td "$FULL_DIR"/full_*_raw 2>/dev/null | head -1)

if [ "$(date +%w)" = "1" ]; then
  xtrabackup --defaults-file="/etc/mysql/.xtrabackup.cnf" --backup --target-dir="$FULL_DIR/full_${DATE}_raw"
  tar -I zstd -cf "$FULL_DIR/full_${DATE}.tar.zst" -C "$FULL_DIR" "full_${DATE}_raw"
  gpg --symmetric --cipher-algo AES256 --batch --yes --passphrase-file /root/.mysql_backup_pass "$FULL_DIR/full_${DATE}.tar.zst"
  rclone copy "$FULL_DIR/full_${DATE}.tar.zst.gpg" "remote-gdrive:MySQL-Backups/"
  rm -rf "$CURRENT_FULL"
  rm -f "$FULL_DIR/full_${DATE}.tar.zst"

else
  if [ -z "$CURRENT_FULL" ]; then
    echo "ERROR: No full backup found! Run full backup first." >&2
    exit 1
  fi
  xtrabackup --defaults-file="/etc/mysql/.xtrabackup.cnf" --backup --target-dir="$INCR_DIR/incr_${DATE}_raw" --incremental-basedir="$CURRENT_FULL"
  tar -I zstd -cf "$INCR_DIR/incr_${DATE}.tar.zst" -C "$INCR_DIR" "incr_${DATE}_raw"
  gpg --symmetric --cipher-algo AES256 --batch --yes --passphrase-file /root/.mysql_backup_pass "$INCR_DIR/incr_${DATE}.tar.zst"
  rclone copy "$INCR_DIR/incr_${DATE}.tar.zst.gpg" "remote-gdrive:MySQL-Backups/"
  rm -rf "$INCR_DIR/incr_${DATE}_raw"
  rm -f "$INCR_DIR/incr_${DATE}.tar.zst"
  find "$INCR_DIR" -name "incr_*.tar.zst.gpg" -mtime +7 -delete
fi
