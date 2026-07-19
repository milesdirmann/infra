#!/usr/bin/env bash
# test-parse-storage.sh
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/parse-storage.sh"
TMP="$(mktemp -d)"
cat > "$TMP/AGENTS.md" <<'EOF'
# X
## Storage
```yaml
storage:
  hot_budget: 2GB
  database: postgres
  deploy: srv
```
EOF
[ "$(parse_storage_field "$TMP/AGENTS.md" hot_budget)" = "2GB" ] || { echo "FAIL hot_budget"; exit 1; }
[ "$(parse_storage_field "$TMP/AGENTS.md" database)" = "postgres" ] || { echo "FAIL database"; exit 1; }
[ "$(parse_storage_field "$TMP/AGENTS.md" cold)" = "" ] || { echo "FAIL cold empty"; exit 1; }
rm -rf "$TMP"
echo "PASS"
