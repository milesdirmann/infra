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

# Shared excludes: regenerable output, and secrets (Doppler is the source of
# truth, no plaintext secret ever reaches the box).
EXCLUDES=(
  --exclude 'node_modules/**'
  --exclude '.venv/**' --exclude 'venv/**'
  --exclude 'target/**' --exclude 'dist/**' --exclude 'build/**'
  --exclude '.next/**' --exclude '__pycache__/**'
  --exclude '.env' --exclude '.env.*' --exclude '*.env' --exclude '.doppler-fallback*'
)

rclone sync "$SRC" "$DST" \
  "${EXCLUDES[@]}" \
  --backup-dir "sbox:backups/.trash/$(date +%Y-%m-%d)" \
  --transfers 4 --log-level NOTICE --log-file /var/log/hetzner-backup.log

# /srv (deployed apps + bare git repos): not on GitHub, single-server risk.
if [ -d /srv ]; then
  rclone sync /srv "sbox:backups/srv" \
    "${EXCLUDES[@]}" \
    --backup-dir "sbox:backups/.trash/$(date +%Y-%m-%d)" \
    --transfers 4 --log-level NOTICE --log-file /var/log/hetzner-backup.log
fi

# Project scan + overview page, generated fresh each run.
PROJ_TOOLS=/root/infra/tools/projects
if [ -x "$PROJ_TOOLS/scan.sh" ]; then
  bash "$PROJ_TOOLS/scan.sh" /root/projects /srv/git /root/infra/dashboard/projects.json \
    >> /var/log/hetzner-backup.log 2>&1 || true
  python3 "$PROJ_TOOLS/generate.py" /root/infra/dashboard/projects.json \
    /root/infra/dashboard/projects.html >> /var/log/hetzner-backup.log 2>&1 || true
  rclone copy /root/infra/dashboard/projects.html sbox:backups/pages \
    --log-level NOTICE --log-file /var/log/hetzner-backup.log || true
fi

# Safety net window: deleted/overwritten files live in dated trash for 30
# days, then purge. Permanent delete on demand = rclone purge that dir.
# Guard: trash only exists after the first deletion has been mirrored.
if rclone lsf "sbox:backups/.trash" --max-depth 1 >/dev/null 2>&1; then
  rclone delete "sbox:backups/.trash" --min-age 30d \
    --log-level NOTICE --log-file /var/log/hetzner-backup.log || true
  rclone rmdirs "sbox:backups/.trash" --leave-root \
    --log-level NOTICE --log-file /var/log/hetzner-backup.log || true
fi
