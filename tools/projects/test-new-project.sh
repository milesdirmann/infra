#!/usr/bin/env bash
# test-new-project.sh
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
export PROJECTS_ROOT="$(mktemp -d)"
bash "$DIR/new-project.sh" zzz-test-scaffold
P="$PROJECTS_ROOT/zzz-test-scaffold"
for f in AGENTS.md CLAUDE.md STATUS.md; do [ -f "$P/$f" ] || { echo "FAIL missing $f"; exit 1; }; done
grep -q "zzz-test-scaffold" "$P/AGENTS.md" || { echo "FAIL name not substituted"; exit 1; }
grep -q "{{NAME}}" "$P/AGENTS.md" && { echo "FAIL placeholder left"; exit 1; }
[ -d "$P/.git" ] || { echo "FAIL no git"; exit 1; }
[ "$(git -C "$P" symbolic-ref --short HEAD)" = "main" ] || { echo "FAIL not main"; exit 1; }
rm -rf "$PROJECTS_ROOT"
echo "PASS"
