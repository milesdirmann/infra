# Project System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a server-first project system where every project is legible to agents and humans from any device, with a four-tier storage contract, Doppler-scoped secrets, and hourly generated status.

**Architecture:** All tooling lives in the infra repo under `tools/projects/` and deploys to the CX33. Projects live at `/root/projects/<name>/` carrying AGENTS.md (canonical), CLAUDE.md (router), STATUS.md (volatile). A scanner emits machine-derived facts to JSON; a generator renders the Personal OS overview page. Local, offline-testable tooling is built and proven against a throwaway project first (Tasks 1-6), then the live server wiring is applied last (Tasks 7-9).

**Tech Stack:** Bash (scanner, scaffold, backup), Python 3 stdlib (JSON to HTML generator), rclone (backup), Doppler (secrets), systemd (timers, service wrapping), Caddy (existing, deploy path).

## Global Constraints

- No em dashes or en dashes in any copy, code comments, or generated output. Commas, colons, periods only.
- Scripts must be idempotent and safe to re-run. Install steps live in header comments.
- Generated HTML uses the Personal OS brand: `<link rel="stylesheet" href="../brand/os.css">`, static values only, no external network calls.
- Archive format everywhere: `tar` + `zstd -3`, sha256 recorded, `filelist.txt` index. Named `<name>-YYYY-MM-DD.tar.zst`.
- Server paths: projects at `/root/projects/<name>/`, deployed apps at `/srv/<app>` with bare repos at `/srv/git/<app>.git`.
- Doppler token files: `/etc/doppler/<name>.token`, root-owned, mode 600.
- Secrets and their fallback caches (`.env*`) are globally gitignored and excluded from backup. No plaintext secret reaches the Storage Box.
- Agents never print secret values; access is only through `doppler run`.
- The existing backup script (`tools/server/rclone-backup.sh`) is extended, never rewritten.
- Bash: `set -euo pipefail` in executable scripts; the scanner uses `set -uo pipefail` so one broken project cannot abort the whole scan.
- Test projects during development use the name prefix `zzz-test-` so they sort last and are unmistakable.

---

### Task 1: Context file templates and the global files

**Files:**
- Create: `tools/projects/templates/AGENTS.md.tmpl`
- Create: `tools/projects/templates/CLAUDE.md.tmpl`
- Create: `tools/projects/templates/STATUS.md.tmpl`
- Create: `tools/projects/templates/global-AGENTS.md` (the real global file, deployed to /root/AGENTS.md)
- Create: `tools/projects/README.md`

**Interfaces:**
- Produces: three template files with `{{NAME}}` and `{{DATE}}` placeholders that `new-project.sh` (Task 4) substitutes; a `storage:` and `secrets:` YAML block inside AGENTS.md.tmpl that `scan.sh` (Task 3) parses.

- [ ] **Step 1: Write CLAUDE.md.tmpl** (exact content, two lines)

```
This file routes. Follow ./AGENTS.md.
```

- [ ] **Step 2: Write AGENTS.md.tmpl**

```markdown
# {{NAME}}

One paragraph: what this is, who it serves, current phase.

## Stack

Runtime, framework, database, deploy target. One line each.

## Conventions

Style, structure, testing rules for this repo. No em or en dashes in any copy.

## Boundaries

What agents must not do here (touch prod data, push without asking, print secrets).

## Storage

```yaml
storage:
  hot_budget: 2GB
  cold: none            # or sbox:datasets/{{NAME}}
  database: none        # or postgres | sqlite
  deploy: none          # or srv
  secrets: none         # or doppler
```
```

- [ ] **Step 3: Write STATUS.md.tmpl**

```markdown
# Status: {{NAME}}        updated: {{DATE}}

## Now

Fresh project. Nothing in flight yet.

## Next

- Define the first milestone.

## Decisions

- {{DATE}}: Project created with the standard scaffold.

## Blocked / waiting

Nothing.
```

- [ ] **Step 4: Write global-AGENTS.md** (durable preferences, drawn from memory and CLAUDE.md)

```markdown
# Global agent instructions

Durable preferences for all work on this server. Project AGENTS.md files
layer on top of this.

## Voice and copy

- Never use em dashes or en dashes. Commas, colons, periods only.
- Plain, direct, results focused. No filler.

## Secrets

- Machine secrets live in Doppler, never in committed files.
- Access secrets only through `doppler run`. Never print a secret value,
  never copy one into a file, transcript, or commit.

## Storage

- Four tiers: code on GitHub, hot on the server under /root/projects and
  /srv, cold on the Storage Box, ephemeral (regenerable) kept nowhere.
- Regenerable output (node_modules, caches, build dirs) is never backed up.
- Large or dormant data goes to the Storage Box, streamed on demand.

## Working style

- Start sessions inside the project directory so context loads.
- Update STATUS.md at the end of any session that changed state.
- Scripts are idempotent and safe to re-run.
```

- [ ] **Step 5: Write tools/projects/README.md** documenting the file set, the placeholder tokens, and that templates are consumed by new-project.sh. Keep to one screen.

- [ ] **Step 6: Commit**

```bash
git add tools/projects/templates tools/projects/README.md
git commit -m "feat(projects): context file templates and global agent instructions"
```

---

### Task 2: Storage-block parser (shared helper)

**Files:**
- Create: `tools/projects/lib/parse-storage.sh`
- Test: `tools/projects/lib/test-parse-storage.sh`

**Interfaces:**
- Produces: `parse_storage_field <agents_md_path> <field>` echoing the value of a key inside the `storage:` YAML block (e.g. `parse_storage_field AGENTS.md database` -> `postgres`), or empty string if absent. Consumed by scan.sh (Task 3).

- [ ] **Step 1: Write the failing test**

```bash
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
```

- [ ] **Step 2: Run it, expect failure**

Run: `bash tools/projects/lib/test-parse-storage.sh`
Expected: FAIL (parse-storage.sh has no function yet, source errors or asserts fail)

- [ ] **Step 3: Implement parse-storage.sh**

```bash
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
```

- [ ] **Step 4: Run test, expect PASS**

Run: `bash tools/projects/lib/test-parse-storage.sh`
Expected: `PASS`

- [ ] **Step 5: Commit**

```bash
git add tools/projects/lib/parse-storage.sh tools/projects/lib/test-parse-storage.sh
git commit -m "feat(projects): storage-block field parser with test"
```

---

### Task 3: The scanner

**Files:**
- Create: `tools/projects/scan.sh`
- Test: `tools/projects/test-scan.sh`

**Interfaces:**
- Consumes: `parse_storage_field` from Task 2.
- Produces: `scan.sh <projects_root> <srv_git_root> <out_json>` writing a JSON array; each element has keys `name, path, managed, last_commit_epoch, dirty, unpushed, status_age_days, hot_bytes, hot_budget, over_budget, database, dump_age_hours, deploy, service_state, error`. Written atomically. Consumed by generate.py (Task 5).

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# test-scan.sh
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(mktemp -d)"; SRV="$(mktemp -d)"; OUT="$(mktemp)"
# managed project with a git repo
mkdir -p "$ROOT/zzz-test-a"
( cd "$ROOT/zzz-test-a" && git init -q && git config user.email t@t && git config user.name t \
  && printf '# A\n## Storage\n```yaml\nstorage:\n  hot_budget: 1GB\n  database: none\n  deploy: none\n```\n' > AGENTS.md \
  && printf 'route\n' > CLAUDE.md && printf '# Status\n' > STATUS.md \
  && git add -A && git commit -qm init )
# unmanaged project (no AGENTS.md)
mkdir -p "$ROOT/zzz-test-b"; printf 'hi\n' > "$ROOT/zzz-test-b/file.txt"
# broken project (dir that will fail git ops but must not abort scan)
mkdir -p "$ROOT/zzz-test-c/.git"   # malformed .git
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
```

- [ ] **Step 2: Run it, expect failure**

Run: `bash tools/projects/test-scan.sh`
Expected: FAIL (`scan.sh: No such file`)

- [ ] **Step 3: Implement scan.sh**

```bash
#!/usr/bin/env bash
# scan.sh -- emit machine-derived facts for every project. Never dies on a
# single broken project. Install: run hourly from the backup timer chain.
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
  # budget bytes
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
```

- [ ] **Step 4: Run test, expect PASS**

Run: `bash tools/projects/test-scan.sh`
Expected: `PASS`

- [ ] **Step 5: Commit**

```bash
git add tools/projects/scan.sh tools/projects/test-scan.sh
git commit -m "feat(projects): hourly scanner emitting machine facts to json"
```

---

### Task 4: The scaffold command

**Files:**
- Create: `tools/projects/new-project.sh`
- Test: `tools/projects/test-new-project.sh`

**Interfaces:**
- Consumes: templates from Task 1.
- Produces: `new-project.sh <name> [--github] [--deploy]` creating `<projects_root>/<name>/` with the three files rendered, `git init` on `main`, `data/dumps/.gitkeep` when appropriate. Honors `PROJECTS_ROOT` env (default `/root/projects`) so tests run in a temp dir.

- [ ] **Step 1: Write the failing test**

```bash
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
```

- [ ] **Step 2: Run it, expect failure**

Run: `bash tools/projects/test-new-project.sh`
Expected: FAIL (`new-project.sh: No such file`)

- [ ] **Step 3: Implement new-project.sh**

```bash
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
```

- [ ] **Step 4: Run test, expect PASS**

Run: `bash tools/projects/test-new-project.sh`
Expected: `PASS`

- [ ] **Step 5: Commit**

```bash
git add tools/projects/new-project.sh tools/projects/test-new-project.sh
git commit -m "feat(projects): scaffold command with template rendering"
```

---

### Task 5: The overview page generator

**Files:**
- Create: `tools/projects/generate.py`
- Test: `tools/projects/test-generate.py`

**Interfaces:**
- Consumes: JSON from Task 3.
- Produces: `generate.py <in_json> <out_html>` writing a Personal OS styled page. Managed projects as rows with status dots; unmanaged flagged; budget overrun and stale dump as warnings.

- [ ] **Step 1: Write the failing test**

```python
# test-generate.py
import json, subprocess, sys, tempfile, os, pathlib
d = pathlib.Path(__file__).parent
data = [
  {"name":"alpha","managed":True,"last_commit_epoch":1,"dirty":0,"unpushed":0,
   "status_age_days":3,"hot_bytes":10,"hot_budget":1000000000,"over_budget":False,
   "database":"postgres","dump_age_hours":5,"deploy":"srv","service_state":"active","error":""},
  {"name":"zzz-test-b","managed":False,"last_commit_epoch":0,"dirty":0,"unpushed":0,
   "status_age_days":-1,"hot_bytes":5,"hot_budget":0,"over_budget":False,
   "database":"none","dump_age_hours":-1,"deploy":"none","service_state":"none","error":""},
]
tj = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False); json.dump(data, tj); tj.close()
th = tempfile.mktemp(suffix=".html")
subprocess.run([sys.executable, str(d/"generate.py"), tj.name, th], check=True)
html = open(th).read()
assert "alpha" in html, "alpha row"
assert "unmanaged" in html.lower(), "unmanaged flag"
assert "os.css" in html, "brand stylesheet linked"
assert "active" in html, "service state shown"
print("PASS")
```

- [ ] **Step 2: Run it, expect failure**

Run: `python3 tools/projects/test-generate.py`
Expected: FAIL (`generate.py` missing)

- [ ] **Step 3: Implement generate.py** (stdlib only, brand-linked, no em/en dashes in output)

```python
#!/usr/bin/env python3
"""generate.py <in_json> <out_html> -- render the projects overview page."""
import json, sys, html, datetime

def human_bytes(n):
    for unit in ("B","KB","MB","GB"):
        if n < 1000: return f"{n:.0f} {unit}"
        n /= 1000
    return f"{n:.0f} TB"

def dot(state):  # returns (css-class, label)
    return {"go":("go","ok"),"hold":("hold","warn"),"stop":("stop","attention")}[state]

def row(p):
    warns = []
    if p["error"]: warns.append("scan error")
    if not p["managed"]: warns.append("unmanaged")
    if p["over_budget"]: warns.append("over budget")
    if p["database"] != "none" and p["dump_age_hours"] > 26: warns.append("stale dump")
    if p["managed"] and p["status_age_days"] > 30: warns.append("status stale")
    state = "go"
    if warns: state = "stop" if ("scan error" in warns or "over budget" in warns) else "hold"
    cls,_ = dot(state)
    name = html.escape(p["name"])
    facts = []
    if p["managed"]:
        facts.append(f"{p['dirty']} dirty" if p["dirty"] else "clean")
        if p["unpushed"]: facts.append(f"{p['unpushed']} unpushed")
        facts.append(f"status {p['status_age_days']}d")
    else:
        facts.append("no AGENTS.md")
    facts.append(human_bytes(p["hot_bytes"]))
    if p["deploy"] == "srv": facts.append(f"svc {html.escape(p['service_state'])}")
    warn_html = f' <span class="warn-tag">{html.escape(", ".join(warns))}</span>' if warns else ""
    return (f'<tr><td><span class="dot {cls}"></span><b>{name}</b>{warn_html}</td>'
            f'<td class="m">{html.escape(" · ".join(facts))}</td></tr>')

def main():
    data = json.load(open(sys.argv[1]))
    data.sort(key=lambda p: (not p["managed"], p["name"]))
    today = datetime.date.today().isoformat()
    rows = "\n".join(row(p) for p in data)
    out = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>PROJECTS / Source of Truth</title>
<link rel="stylesheet" href="../brand/os.css">
<style>.warn-tag{{font-family:var(--mono);font-size:10px;color:var(--hold);margin-left:8px}}</style>
</head><body><div class="wrap">
<header><div class="mast-top">
<span class="eyebrow">Personal OS / Projects 002</span>
<span class="eyebrow">generated hourly</span></div>
<h1>Projects</h1>
<p class="mast-sub">Every project on the server, with facts that cannot lie.
Generated from a scan, not hand maintained. Last generated {today}.</p></header>
<section><div class="sec-head"><h2>All projects</h2>
<span class="eyebrow">PRJ / live scan</span></div>
<table><thead><tr><th>Project</th><th>State</th></tr></thead>
<tbody>
{rows}
</tbody></table></section>
<footer><span>Personal OS · milesdirmann/infra</span>
<span>regenerated each hour on the CX33</span></footer>
</div></body></html>"""
    open(sys.argv[2], "w").write(out)

if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run test, expect PASS**

Run: `python3 tools/projects/test-generate.py`
Expected: `PASS`

- [ ] **Step 5: Commit**

```bash
git add tools/projects/generate.py tools/projects/test-generate.py
git commit -m "feat(projects): overview page generator in Personal OS brand"
```

---

### Task 6: End-to-end local dry run

**Files:**
- Create: `tools/projects/test-e2e.sh`

**Interfaces:**
- Consumes: Tasks 2-5 together.
- Produces: proof the scaffold -> scan -> generate chain works on a throwaway project with no server access.

- [ ] **Step 1: Write the e2e test**

```bash
#!/usr/bin/env bash
# test-e2e.sh -- scaffold, scan, generate, all in temp dirs.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
export PROJECTS_ROOT="$(mktemp -d)"; SRV="$(mktemp -d)"; J="$(mktemp)"; H="$(mktemp --suffix=.html)"
bash "$DIR/new-project.sh" zzz-test-e2e --deploy
bash "$DIR/scan.sh" "$PROJECTS_ROOT" "$SRV" "$J"
python3 "$DIR/generate.py" "$J" "$H"
grep -q "zzz-test-e2e" "$H" || { echo "FAIL project not on page"; exit 1; }
python3 -c "import json;assert json.load(open('$J'))[0]['managed'] is True" || { echo "FAIL not managed"; exit 1; }
rm -rf "$PROJECTS_ROOT" "$SRV" "$J" "$H"
echo "PASS e2e"
```

- [ ] **Step 2: Run it, expect PASS** (all components already built)

Run: `bash tools/projects/test-e2e.sh`
Expected: `PASS e2e`

- [ ] **Step 3: Commit**

```bash
git add tools/projects/test-e2e.sh
git commit -m "test(projects): end-to-end scaffold-scan-generate dry run"
```

---

### Task 7: Extend the backup to /srv and wire the scan into the timer

**Files:**
- Modify: `tools/server/rclone-backup.sh` (after the existing projects sync, before the trash-purge block)
- Create: `tools/projects/install-on-server.sh`

**Interfaces:**
- Consumes: scan.sh, generate.py.
- Produces: a live hourly chain on the CX33: backup projects, backup /srv, run scan, regenerate page, mirror page to the box.

- [ ] **Step 1: Add /srv backup + scan/generate to rclone-backup.sh**

Insert after the existing `rclone sync "$SRC" "$DST" ...` block:

```bash
# --- /srv (deployed apps + bare repos) : not on GitHub, single-server risk ---
rclone sync /srv "sbox:backups/srv" \
  --exclude 'node_modules/**' --exclude 'target/**' --exclude '.next/**' \
  --backup-dir "sbox:backups/.trash/$(date +%Y-%m-%d)" \
  --transfers 4 --log-level NOTICE --log-file /var/log/hetzner-backup.log

# --- project scan + overview page ---
PROJ_TOOLS=/root/infra/tools/projects
if [ -x "$PROJ_TOOLS/scan.sh" ]; then
  bash "$PROJ_TOOLS/scan.sh" /root/projects /srv/git /root/infra/dashboard/projects.json \
    >> /var/log/hetzner-backup.log 2>&1 || true
  python3 "$PROJ_TOOLS/generate.py" /root/infra/dashboard/projects.json \
    /root/infra/dashboard/projects.html >> /var/log/hetzner-backup.log 2>&1 || true
  rclone copy /root/infra/dashboard/projects.html sbox:backups/pages \
    --log-level NOTICE --log-file /var/log/hetzner-backup.log || true
fi
```

- [ ] **Step 2: Write install-on-server.sh** (idempotent deploy of the infra repo tools to the server)

```bash
#!/usr/bin/env bash
# install-on-server.sh -- run ON the CX33. Ensures the infra repo is present
# at /root/infra and tools are executable. Safe to re-run.
set -euo pipefail
if [ -d /root/infra/.git ]; then
  git -C /root/infra pull --ff-only
else
  gh repo clone milesdirmann/infra /root/infra 2>/dev/null || git clone https://github.com/milesdirmann/infra.git /root/infra
fi
chmod +x /root/infra/tools/projects/*.sh /root/infra/tools/projects/lib/*.sh
cp /root/infra/tools/server/rclone-backup.sh /usr/local/bin/rclone-backup.sh
chmod +x /usr/local/bin/rclone-backup.sh
# global agent file
install -D -m 644 /root/infra/tools/projects/templates/global-AGENTS.md /root/AGENTS.md
[ -f /root/.claude/CLAUDE.md ] || { mkdir -p /root/.claude; printf 'This file routes. Follow /root/AGENTS.md.\n' > /root/.claude/CLAUDE.md; }
echo "installed. next backup run will scan and generate."
```

- [ ] **Step 3: Verify locally that the modified backup script still parses**

Run: `bash -n tools/server/rclone-backup.sh`
Expected: no output (syntax OK)

- [ ] **Step 4: Commit**

```bash
git add tools/server/rclone-backup.sh tools/projects/install-on-server.sh
git commit -m "feat(projects): back up /srv, run scan+generate in the hourly chain"
```

- [ ] **Step 5: Deploy and verify on the CX33** (live)

```bash
git push
ssh server 'bash /dev/stdin' < tools/projects/install-on-server.sh
ssh server 'PROJ=/root/infra/tools/projects; bash $PROJ/scan.sh /root/projects /srv/git /root/infra/dashboard/projects.json && python3 $PROJ/generate.py /root/infra/dashboard/projects.json /root/infra/dashboard/projects.html && head -5 /root/infra/dashboard/projects.html'
```
Expected: HTML head prints; no errors. Confirms scan+generate run against real /root/projects.

---

### Task 8: Doppler secrets, scoped per project

**Files:**
- Create: `tools/projects/doppler-setup.md` (operator runbook, since login is interactive)
- Create: `tools/projects/doppler-run-wrapper.md` (systemd ExecStart pattern)
- Modify: `.gitignore` (repo root) to exclude `.env*` and doppler fallback caches

**Interfaces:**
- Consumes: none in code (Doppler login is Miles-only).
- Produces: documented, repeatable secret wiring; global gitignore guarantees no secret is committed.

- [ ] **Step 1: Add ignore rules** to repo-root `.gitignore` (create if absent)

```
# secrets: sourced from Doppler, never committed
.env
.env.*
*.env
.doppler-fallback*
/etc/doppler/*.token
```

- [ ] **Step 2: Write doppler-setup.md** with the exact operator steps

```markdown
# Doppler setup (operator, one time per project)

Prereq (Miles, once on the CX33): `doppler login`

Per project:
1. `doppler projects create <name>`
2. Add secrets in the dashboard (paste current keys, rotate on the way in).
3. Create a scoped service token, read-only, config `prd`:
   `doppler configs tokens create ci --project <name> --config prd --plain > /etc/doppler/<name>.token`
   `chmod 600 /etc/doppler/<name>.token`
4. In the project set: `storage.secrets: doppler` in AGENTS.md.

A token in /etc/doppler/<name>.token can read that project's secrets and
nothing else. Never print a token or a secret value.
```

- [ ] **Step 3: Write doppler-run-wrapper.md** (how a deployed service consumes it)

```markdown
# Running a service with Doppler secrets

Systemd ExecStart wraps the process so secrets live in memory only:

    Environment=DOPPLER_TOKEN_FILE=/etc/doppler/<name>.token
    ExecStart=/bin/sh -c 'DOPPLER_TOKEN=$(cat $DOPPLER_TOKEN_FILE) doppler run --fallback --command "node server.js"'

--fallback keeps an encrypted local cache so a Doppler outage or offline
restart still works. The cache is gitignored and excluded from backup.
```

- [ ] **Step 4: Verify ignore rules work**

Run: `printf 'SECRET=x\n' > .env && git check-ignore .env && rm .env`
Expected: prints `.env` (confirming it is ignored)

- [ ] **Step 5: Commit**

```bash
git add .gitignore tools/projects/doppler-setup.md tools/projects/doppler-run-wrapper.md
git commit -m "feat(projects): Doppler secrets convention, scoped tokens, ignore rules"
```

---

### Task 9: Backup exclusions for secrets + final live verification

**Files:**
- Modify: `tools/server/rclone-backup.sh` (add secret excludes to both sync commands)

**Interfaces:**
- Consumes: everything prior.
- Produces: guarantee that no `.env*` or token reaches the Storage Box, and a verified live run of the whole chain.

- [ ] **Step 1: Add secret excludes** to both `rclone sync` commands in rclone-backup.sh

Add these exclude flags to the projects sync and the /srv sync:

```bash
  --exclude '.env' --exclude '.env.*' --exclude '*.env' --exclude '.doppler-fallback*'
```

- [ ] **Step 2: Syntax check**

Run: `bash -n tools/server/rclone-backup.sh`
Expected: no output

- [ ] **Step 3: Commit and deploy**

```bash
git add tools/server/rclone-backup.sh
git commit -m "feat(projects): exclude secrets from backup mirror"
git push
ssh server 'bash /dev/stdin' < tools/projects/install-on-server.sh
```

- [ ] **Step 4: Live verification of the full chain**

```bash
ssh server 'sudo systemctl start hetzner-backup.service; sleep 20; tail -15 /var/log/hetzner-backup.log'
ssh server 'ls -la /root/infra/dashboard/projects.html /root/infra/dashboard/projects.json'
# confirm /srv is now on the box and no env leaked
rclone lsf sbox:backups/srv 2>/dev/null | head
printf 'SECRET=x\n' | ssh server 'cat > /root/projects/zzz-test-secret.env'
ssh server 'sudo systemctl start hetzner-backup.service; sleep 15'
rclone lsf sbox:backups/projects 2>/dev/null | grep -c 'zzz-test-secret.env' | grep -q '^0$' && echo "GOOD: env excluded from backup"
ssh server 'rm -f /root/projects/zzz-test-secret.env'
```
Expected: log shows scan+generate ran, page and json exist, `/srv` listed on the box, `GOOD: env excluded from backup` prints.

- [ ] **Step 5: Add projects.html link to the infra dashboard** and commit

Add to `dashboard/index.html` repo-index section a link row: `<tr><td class="m"><a href="projects.html">projects.html</a></td><td>Live project overview, generated hourly</td></tr>`

```bash
git add dashboard/index.html
git commit -m "feat(projects): link the projects overview from the infra dashboard"
git push
```

---

## Self-Review

**Spec coverage:** layout (T1), storage-block parsing (T2), scanner with all declared fields and never-die behavior (T3), scaffold (T4), overview page (T5), e2e proof (T6), /srv backup + scan wiring + global files deploy (T7), Doppler scoped secrets + ignore (T8), secret backup exclusion + full live verification + dashboard link (T9). Error handling (atomic JSON write in T3, per-project error field, unmanaged flagged not hidden), testing (each task TDD + T6 e2e + T9 live), and out-of-scope items (Mac overhaul, 19-dir migration, Notion) all honored. Covered.

**Placeholder scan:** none. Every code step carries full content.

**Type consistency:** `parse_storage_field` signature identical in T2 and T3. JSON keys emitted in T3 match those consumed in T5 (`managed, over_budget, dump_age_hours, service_state, ...`). `PROJECTS_ROOT` env consistent across T4/T6. Page brand link (`../brand/os.css`) consistent T5 and matches existing pages.
