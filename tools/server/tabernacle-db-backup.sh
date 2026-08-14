#!/usr/bin/env bash
# Nightly logical backup of the Tabernacle Supabase database -> Storage Box.
# Managed via milesdirmann/infra (tools/server/). Secrets: /root/.tabernacle-db.env
set -euo pipefail

source /root/.tabernacle-db.env
if [ -z "${DATABASE_URL:-}" ]; then
  echo "tabernacle-db-backup: DATABASE_URL not set in /root/.tabernacle-db.env — skipping dump" >&2
  exit 1
fi

DIR=/root/backups/tabernacle-db
mkdir -p "$DIR"
STAMP=$(date -u +%Y%m%d-%H%M)
OUT="$DIR/tabernacle-$STAMP.dump"

# Custom format: compressed, restorable table-by-table with pg_restore.
pg_dump "$DATABASE_URL" --format=custom --no-owner --file="$OUT.partial"
mv "$OUT.partial" "$OUT"
echo "dumped $(du -h "$OUT" | cut -f1) -> $OUT"

rclone copy "$DIR" sbox:backups/tabernacle-db --include "tabernacle-*.dump" \
  --log-level NOTICE --log-file /var/log/tabernacle-db-backup.log

# Retention: 7 days local, 60 days on the box.
find "$DIR" -name "tabernacle-*.dump" -mtime +7 -delete
rclone delete sbox:backups/tabernacle-db --min-age 60d \
  --log-level NOTICE --log-file /var/log/tabernacle-db-backup.log || true
echo "ok"
