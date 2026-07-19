#!/usr/bin/env bash
# parse-storage.sh -- read a field from the storage: block of an AGENTS.md.
# Usage: parse_storage_field <agents_md_path> <field>
parse_storage_field() {
  local file="$1" field="$2"
  [ -f "$file" ] || { echo ""; return 0; }
  awk -v f="$field" '
    /^```yaml/ {inyaml=1; next}
    /^```/ {inyaml=0}
    inyaml && $1 == f":" { $1=""; sub(/^[ \t]+/, ""); sub(/[ \t]*#.*$/, ""); sub(/[ \t]+$/,""); print; exit }
  ' "$file"
}
