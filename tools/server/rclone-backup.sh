#!/usr/bin/env bash
# Runs ON THE VPS (as root): mirror active projects to the Hetzner Storage Box.
# One-time on the VPS:
#   apt install rclone
#   rclone config create sbox sftp host u634219.your-storagebox.de user u634219 port 23 key_file /root/.ssh/id_ed25519
#   (the VPS key must be in the box authorized_keys; box path is home relative, never "/")
# Install (script to /usr/local/bin, units to systemd):
#   cp tools/server/rclone-backup.sh /usr/local/bin/ && chmod +x /usr/local/bin/rclone-backup.sh
#   cp tools/server/hetzner-backup.{service,timer} /etc/systemd/system/
#   systemctl daemon-reload && systemctl enable --now hetzner-backup.timer
set -euo pipefail

SRC="${SRC:-/root/projects}"
DST="${DST:-sbox:backups/projects}"

rclone sync "$SRC" "$DST" \
  --exclude 'node_modules/**' \
  --exclude '.venv/**' --exclude 'venv/**' \
  --exclude 'target/**' --exclude 'dist/**' --exclude 'build/**' \
  --exclude '.next/**' --exclude '__pycache__/**' \
  --backup-dir "sbox:backups/.trash/$(date +%Y-%m-%d)" \
  --transfers 4 --log-level NOTICE --log-file /var/log/hetzner-backup.log
