#!/usr/bin/env bash
# scan.sh -- emit machine-derived facts for every project. Never dies on a
# single broken project. Run hourly from the backup timer chain.
# Usage: scan.sh <projects_root> <srv_git_root> <out_json>
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib/parse-storage.sh"
ROOT="${1:?projects root}"; SRVGIT="${2:?srv git root}"; OUT="${3:?out json}"
NOW="$(date +%s)"
json_escape() { python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))' ; }

scan_one() { # <dir> -> one JSON object on stdout
  local d="$1" name err="" managed=false
  name="$(basename "$d")"
  local last=0 dirty=0 unpushed=0 status_age=-1 hot=0 budget="" db="none" dumpage=-1 deploy="none" svc="none"
  {
    [ -f "$d/AGENTS.md" ] && managed=true
    if [ -d "$d/.git" ]; then
      last="$(git -C "$d" log -1 --format=%ct 2>/dev/null || echo 0)"
      dirty="$(git -C "$d" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
      unpushed="$(git -C "$d" log --branches --not --remotes --oneline 2>/dev/null | wc -l | tr -d ' ')"
    fi
    if [ -f "$d/STATUS.md" ]; then
      local mt; mt="$(stat -c %Y "$d/STATUS.md" 2>/dev/null || echo "$NOW")"
      status_age=$(( (NOW - mt) / 86400 ))
    fi
    hot="$(du -sb --exclude=node_modules --exclude=.venv --exclude=target --exclude=.next "$d" 2>/dev/null | cut -f1)"
    [ -z "$hot" ] && hot=0
    budget="$(parse_storage_field "$d/AGENTS.md" hot_budget)"
    db="$(parse_storage_field "$d/AGENTS.md" database)"; [ -z "$db" ] && db="none"
    deploy="$(parse_storage_field "$d/AGENTS.md" deploy)"; [ -z "$deploy" ] && deploy="none"
    if [ "$db" != "none" ] && [ -d "$d/data/dumps" ]; then
      local newest; newest="$(find "$d/data/dumps" -type f -printf '%T@\n' 2>/dev/null | sort -rn | head -1 | cut -d. -f1)"
      [ -n "$newest" ] && dumpage=$(( (NOW - newest) / 3600 ))
    fi
    if [ "$deploy" = "srv" ]; then
      svc="$(systemctl is-active "$name" 2>/dev/null || echo inactive)"
    fi
  } || err="scan error"
  local budbytes=0 over=false
  case "$budget" in
    *GB) budbytes=$(( ${budget%GB} * 1000000000 ));;
    *MB) budbytes=$(( ${budget%MB} * 1000000 ));;
  esac
  [ "$budbytes" -gt 0 ] && [ "$hot" -gt "$budbytes" ] && over=true
  printf '{"name":"%s","path":%s,"managed":%s,"last_commit_epoch":%s,"dirty":%s,"unpushed":%s,"status_age_days":%s,"hot_bytes":%s,"hot_budget":%s,"over_budget":%s,"database":"%s","dump_age_hours":%s,"deploy":"%s","service_state":"%s","error":"%s"}' \
    "$name" "$(printf '%s' "$d" | json_escape)" "$managed" "${last:-0}" "$dirty" "$unpushed" "$status_age" "$hot" "$budbytes" "$over" "$db" "$dumpage" "$deploy" "$svc" "$err"
}

TMP="$(mktemp)"
{
  echo "["
  first=1
  for d in "$ROOT"/*/ "$SRVGIT"/*.git; do
    [ -e "$d" ] || continue
    [ "$first" -eq 1 ] || echo ","
    first=0
    scan_one "${d%/}"
  done
  echo "]"
} > "$TMP"
mv "$TMP" "$OUT"
