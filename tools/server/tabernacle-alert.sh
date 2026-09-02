#!/usr/bin/env bash
# Sends a short failure alert for the Tabernacle backup jobs.
# Managed via milesdirmann/infra (tools/server/). Config: /root/.tabernacle-db.env
#
# Channel is whatever is configured in the env file:
#   ALERT_NTFY_TOPIC=<topic>   -> push via ntfy.sh (no account needed)
#   ALERT_WEBHOOK_URL=<url>    -> plain POST of the message body
# With neither set it still logs and leaves a marker file, so a later check
# can see that something failed even though nobody was told.
#
# Messages stay generic on purpose: they travel to a third party, so they name
# the host and the job and nothing about the data.
set -uo pipefail
MSG=${1:-'Tabernacle backup job failed on cx33'}
MARKER=/var/lib/tabernacle-backup-alert.last
source /root/.tabernacle-db.env 2>/dev/null || true

mkdir -p /var/lib
printf '%s\n' "$(date -uIs) $MSG" > "$MARKER"
logger -t tabernacle-alert -p daemon.err "$MSG"

sent=no
if [ -n "${ALERT_NTFY_TOPIC:-}" ]; then
  curl -fsS --max-time 20 -H 'Title: Tabernacle backup' -H 'Priority: high' -H 'Tags: warning' \
    -d "$MSG" "https://ntfy.sh/${ALERT_NTFY_TOPIC}" >/dev/null && sent=yes
fi
if [ -n "${ALERT_WEBHOOK_URL:-}" ]; then
  curl -fsS --max-time 20 -H 'Content-Type: application/json' \
    -d "{\"text\":\"$MSG\"}" "$ALERT_WEBHOOK_URL" >/dev/null && sent=yes
fi
echo "tabernacle-alert: $MSG (delivered=$sent)"
