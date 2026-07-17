#!/usr/bin/env bash
# Runs ON THE VPS: mirror active projects to the Hetzner Storage Box.
# One-time on the VPS:
#   apt install rclone
#   rclone config create sbox sftp host uXXXXXX.your-storagebox.de user uXXXXXX port 23 key_file /home/dev/.ssh/id_ed25519
#   (upload the key first: ssh-copy-id -p 23 uXXXXXX@uXXXXXX.your-storagebox.de)
# Install the timer:
#   sudo cp tools/server/hetzner-backup.{service,timer} /etc/systemd/system/
#   sudo systemctl enable --now hetzner-backup.timer
set -euo pipefail

SRC="${SRC:-/home/dev/projects}"
DST="${DST:-sbox:backups/projects}"

rclone sync "$SRC" "$DST" \
  --exclude 'node_modules/**' \
  --exclude '.venv/**' --exclude 'venv/**' \
  --exclude 'target/**' --exclude 'dist/**' --exclude 'build/**' \
  --exclude '.next/**' --exclude '__pycache__/**' \
  --backup-dir "sbox:backups/.trash/$(date +%Y-%m-%d)" \
  --transfers 4 --log-level NOTICE --log-file /var/log/hetzner-backup.log
