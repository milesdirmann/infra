#!/usr/bin/env bash
# Verifies a recent Tabernacle dump exists locally and on the Storage Box.
set -uo pipefail
DIR=/root/backups/tabernacle-db
MAXAGE_H=30
newest=$(find "$DIR" -name 'tabernacle-*.dump' -mmin -$((MAXAGE_H*60)) 2>/dev/null | head -1)
if [ -z "$newest" ]; then
  /usr/local/bin/tabernacle-alert.sh "No Tabernacle DB dump newer than ${MAXAGE_H}h on cx33 - backups may have stopped"
  exit 1
fi
if ! rclone lsf sbox:backups/tabernacle-db --include 'tabernacle-*.dump' --max-age ${MAXAGE_H}h 2>/dev/null | grep -q .; then
  /usr/local/bin/tabernacle-alert.sh "Tabernacle dump exists locally but nothing recent on the Storage Box"
  exit 1
fi
echo "backup check ok: $(basename "$newest")"
