#!/usr/bin/env bash
# test-scan.sh
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(mktemp -d)"; SRV="$(mktemp -d)"; OUT="$(mktemp)"
mkdir -p "$ROOT/zzz-test-a"
( cd "$ROOT/zzz-test-a" && git init -q && git config user.email t@t && git config user.name t \
  && printf '# A\n## Storage\n```yaml\nstorage:\n  hot_budget: 1GB\n  database: none\n  deploy: none\n```\n' > AGENTS.md \
  && printf 'route\n' > CLAUDE.md && printf '# Status\n' > STATUS.md \
  && git add -A && git commit -qm init )
mkdir -p "$ROOT/zzz-test-b"; printf 'hi\n' > "$ROOT/zzz-test-b/file.txt"
mkdir -p "$ROOT/zzz-test-c/.git"
bash "$DIR/scan.sh" "$ROOT" "$SRV" "$OUT"
python3 - "$OUT" <<'PY'
import json,sys
d={x["name"]:x for x in json.load(open(sys.argv[1]))}
assert d["zzz-test-a"]["managed"] is True, "a managed"
assert d["zzz-test-b"]["managed"] is False, "b unmanaged"
assert "zzz-test-c" in d, "c present despite broken git"
print("PASS")
PY
rm -rf "$ROOT" "$SRV" "$OUT"
