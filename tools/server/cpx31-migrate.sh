#!/usr/bin/env bash
# CPX31 exfiltration v2: tar streams, not per-file SFTP.
# v1 died on 278k small files x 150ms RTT. One stream per tree instead.
# clickhouse.tar.zst and db-dumps/liquidco-engine.db already done + verified.
set -uo pipefail
exec >> /root/migrate2.log 2>&1

ARC="sbox:archive/cpx31"
SHAFILE=/root/migrate2-sha256.txt
ok()   { echo "[$(date -u +%H:%M:%S)] PHASE-OK $1"; }
fail() { echo "[$(date -u +%H:%M:%S)] PHASE-FAIL $1"; }
say()  { echo "[$(date -u +%H:%M:%S)] $1"; }

EXC=(--exclude=.venv --exclude=venv --exclude=node_modules --exclude=__pycache__
     --exclude=.cache --exclude=.npm --exclude=target --exclude=.next
     --exclude='*/models/ggml-*.bin' --exclude='*.sock')

say "=== MIGRATION v2 START $(date -u) ==="

# ---- 1. quiesce: stop the broken writers so the archive is consistent ----
# All three are already failing (liquidco stale+erroring, action-ingest crash
# looping, codex serving a product being rebuilt). Reversible: systemctl start.
for s in liquidco-engine codex-app-server-avo avo-action-ingest cron; do
  systemctl stop "$s" 2>/dev/null && say "stopped $s" || say "could not stop $s (may not exist)"
done
sleep 2
ok "quiesce"

# ---- 2. FINAL liquidco db snapshot, now that writers are stopped ----
sqlite3 /home/liquidco/engine/engine.db ".backup '/root/db-dumps/liquidco-engine-final.db'" 2>/dev/null
if [ -f /root/db-dumps/liquidco-engine-final.db ]; then
  INTEG=$(sqlite3 /root/db-dumps/liquidco-engine-final.db "PRAGMA integrity_check;" 2>/dev/null)
  ROWS=$(sqlite3 /root/db-dumps/liquidco-engine-final.db "SELECT count(*) FROM tracked_listings;" 2>/dev/null)
  say "final db: integrity=$INTEG tracked_listings=$ROWS"
  sha256sum /root/db-dumps/liquidco-engine-final.db >> "$SHAFILE"
  rclone copy /root/db-dumps/liquidco-engine-final.db "$ARC/db-dumps/" --log-level ERROR \
    && ok "liquidco-db-final" || fail "liquidco-db-final"
else
  fail "liquidco-db-final"
fi

# ---- 3. tar each tree: one stream, sha256 recorded, listing uploaded ----
tar_tree() { # path  name
  local path="$1" name="$2"
  [ -e "$path" ] || { say "skip $name (missing)"; return; }
  say "listing $name..."
  find "$path" -type f \
    -not -path "*/.venv/*" -not -path "*/venv/*" -not -path "*/node_modules/*" \
    -not -path "*/__pycache__/*" -not -path "*/.cache/*" -not -path "*/.npm/*" \
    -not -path "*/target/*" -printf '%10s  %TY-%Tm-%Td  %p\n' 2>/dev/null \
    | sort -k4 > "/root/$name.filelist.txt"
  rclone copy "/root/$name.filelist.txt" "$ARC/filelists/" --log-level ERROR

  say "tar+zstd $name ($(du -sh --exclude=node_modules --exclude=.venv "$path" 2>/dev/null | awk '{print $1}'))..."
  # tar exit 1 = "file changed while reading" (tolerable); 2 = fatal
  set -o pipefail
  tar -C "$(dirname "$path")" "${EXC[@]}" \
      --warning=no-file-changed --warning=no-file-removed \
      -cf - "$(basename "$path")" 2>/dev/null \
    | zstd -3 -T4 \
    | tee >(sha256sum | awk -v n="$name.tar.zst" '{print $1"  "n}' >> "$SHAFILE") \
    | rclone rcat "$ARC/$name.tar.zst" --log-level ERROR
  local rc=${PIPESTATUS[0]}
  if [ "$rc" -le 1 ]; then ok "$name"; else fail "$name (tar rc=$rc)"; fi
}

tar_tree /home/avo       home-avo
tar_tree /home/scouq     home-scouq
tar_tree /home/liquidco  home-liquidco
tar_tree /home/gold      home-gold
tar_tree /home/invest    home-invest

# ---- 4. /root work dirs, one tar ----
say "listing + tarring root work dirs..."
find /root/argus-source /root/argus-leads /root/argus-bin /root/avo-project -type f \
  -not -path "*/target/*" -not -path "*/node_modules/*" -printf '%10s  %TY-%Tm-%Td  %p\n' 2>/dev/null \
  | sort -k4 > /root/root-work.filelist.txt
rclone copy /root/root-work.filelist.txt "$ARC/filelists/" --log-level ERROR
set -o pipefail
tar -C /root "${EXC[@]}" --warning=no-file-changed \
    -cf - argus-source argus-leads argus-bin avo-project 2>/dev/null \
  | zstd -3 -T4 \
  | tee >(sha256sum | awk '{print $1"  root-work.tar.zst"}' >> "$SHAFILE") \
  | rclone rcat "$ARC/root-work.tar.zst" --log-level ERROR
[ "${PIPESTATUS[0]}" -le 1 ] && ok "root-work" || fail "root-work"

# ---- 5. system bundle: configs, certs, units, crontabs, docker volumes, redis ----
say "system bundle..."
crontab -l > /root/crontab-root.txt 2>/dev/null || true
for u in avo scouq invest liquidco gold; do crontab -l -u "$u" > "/root/crontab-$u.txt" 2>/dev/null || true; done
dpkg --get-selections > /root/dpkg-selections.txt 2>/dev/null || true
systemctl list-unit-files --type=service --state=enabled --no-legend > /root/enabled-services.txt 2>/dev/null || true
ip addr > /root/net-config.txt 2>/dev/null || true
set -o pipefail
tar -cf - \
  /etc/nginx /etc/letsencrypt /etc/cron.d /etc/systemd/system \
  /var/lib/docker/volumes /var/lib/redis \
  /root/crontab-*.txt /root/dpkg-selections.txt /root/enabled-services.txt /root/net-config.txt \
  /root/.gitconfig /root/.bashrc /home/avo/.env 2>/dev/null \
  | zstd -3 \
  | tee >(sha256sum | awk '{print $1"  system-bundle.tar.zst"}' >> "$SHAFILE") \
  | rclone rcat "$ARC/system-bundle.tar.zst" --log-level ERROR
[ "${PIPESTATUS[0]}" -le 1 ] && ok "system-bundle" || fail "system-bundle"

# ---- 6. stray big file ----
[ -f /tmp/redfin_city.gz ] && { rclone copy /tmp/redfin_city.gz "$ARC/stray/" --log-level ERROR && ok "redfin"; }

# ---- 7. small live-ish code -> CX33 (rsync pipelines small files well) ----
say "rsync liquidco/gold/invest -> CX33..."
rsync -az --timeout=120 -e "ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15" \
  --exclude node_modules --exclude .venv --exclude __pycache__ \
  /home/liquidco /home/gold /home/invest \
  root@89.167.110.196:/root/projects/cpx31-imports/ \
  && ok "cx33-imports" || fail "cx33-imports"

# ---- 8. checksums + manifest ----
rclone copy "$SHAFILE" "$ARC/" --log-level ERROR
{
  echo "CPX31 archive manifest, created $(date -u)"
  echo
  echo "== sha256 (computed on CPX31 as each stream was written) =="
  cat /root/migrate-sha256.txt 2>/dev/null
  cat "$SHAFILE" 2>/dev/null
  echo
  echo "== archive size =="
  rclone size "$ARC" 2>/dev/null
  echo
  echo "== git repos preserved (uncommitted/unpushed at archive time) =="
  cat /root/git-inventory.txt 2>/dev/null
} > /root/MANIFEST.txt
rclone copy /root/MANIFEST.txt "$ARC/" --log-level ERROR
rclone copy /root/migrate2.log "$ARC/logs/" --log-level ERROR || true

say "=== MIGRATION v2 DONE $(date -u) ==="
