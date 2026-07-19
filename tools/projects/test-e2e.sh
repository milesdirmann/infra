#!/usr/bin/env bash
# test-e2e.sh -- scaffold, scan, generate, all in temp dirs.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
export PROJECTS_ROOT="$(mktemp -d)"; SRV="$(mktemp -d)"; J="$(mktemp)"; H="$(mktemp).html"
bash "$DIR/new-project.sh" zzz-test-e2e --deploy
bash "$DIR/scan.sh" "$PROJECTS_ROOT" "$SRV" "$J"
python3 "$DIR/generate.py" "$J" "$H"
grep -q "zzz-test-e2e" "$H" || { echo "FAIL project not on page"; exit 1; }
python3 -c "import json;assert json.load(open('$J'))[0]['managed'] is True" || { echo "FAIL not managed"; exit 1; }
rm -rf "$PROJECTS_ROOT" "$SRV" "$J" "$H"
echo "PASS e2e"
