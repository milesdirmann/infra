#!/usr/bin/env bash
# new-project.sh -- scaffold a project from templates.
# Usage: new-project.sh <name> [--github] [--deploy]
# Env: PROJECTS_ROOT (default /root/projects)
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
TPL="$DIR/templates"
NAME="${1:?project name}"; shift || true
ROOT="${PROJECTS_ROOT:-/root/projects}"
DEST="$ROOT/$NAME"
[ -e "$DEST" ] && { echo "exists: $DEST" >&2; exit 1; }
TODAY="$(date +%Y-%m-%d)"
mkdir -p "$DEST"
render() { sed -e "s/{{NAME}}/$NAME/g" -e "s/{{DATE}}/$TODAY/g" "$1"; }
render "$TPL/AGENTS.md.tmpl"  > "$DEST/AGENTS.md"
render "$TPL/CLAUDE.md.tmpl"  > "$DEST/CLAUDE.md"
render "$TPL/STATUS.md.tmpl"  > "$DEST/STATUS.md"
( cd "$DEST" && git init -qb main && git add -A && git commit -qm "scaffold: $NAME" )
for arg in "$@"; do
  case "$arg" in
    --github) command -v gh >/dev/null && ( cd "$DEST" && gh repo create "$NAME" --private --source=. --push ) || echo "gh not available, skipped" >&2 ;;
    --deploy) mkdir -p "$DEST/data/dumps" && touch "$DEST/data/dumps/.gitkeep" ;;
  esac
done
echo "created $DEST"
