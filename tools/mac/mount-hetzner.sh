#!/usr/bin/env bash
# Mount Hetzner locations as Finder volumes via rclone nfsmount (no FUSE needed).
# This is THE Finder integration (chosen 2026-07-16, free). Mountain Duck is
# the optional paid upgrade if cloud badges / offline pinning are ever wanted
# — see docs/finder-remote-volumes.md.
#
# One-time Mac setup:
#   brew install rclone   # Homebrew's rclone has no `mount` on macOS; we use `nfsmount`
#   bash tools/mac/mount-hetzner.sh configure   # writes the rclone remotes
#
# Then: bash tools/mac/mount-hetzner.sh mount | unmount | status
set -euo pipefail

# ---- current fleet (override via env if these change) ----
VPS_HOST="${VPS_HOST:-89.167.110.196}"          # cx33-server, Helsinki
VPS_USER="${VPS_USER:-root}"
SBOX_HOST="${SBOX_HOST:-u634219.your-storagebox.de}"  # cold-storage BX11
SBOX_USER="${SBOX_USER:-u634219}"
VPS_PATH="${VPS_PATH:-/root/projects}"  # live projects dir on the VPS
# -----------------------------------------------------------

VOL_VPS="${VOL_VPS:-Server}"       # folder name for live VPS projects
VOL_SBOX="${VOL_SBOX:-Storage}"    # folder name for the 1TB Storage Box
MNT_BASE="$HOME/Hetzner"

configure() {
  rclone config create cpx sftp host "$VPS_HOST" user "$VPS_USER" key_file "$HOME/.ssh/id_ed25519"
  # Storage Box speaks SFTP on port 23
  rclone config create sbox sftp host "$SBOX_HOST" user "$SBOX_USER" port 23 key_file "$HOME/.ssh/id_ed25519"
  echo "Remotes written. Test with: rclone lsd cpx: && rclone lsd sbox:"
}

# capture mount output first: `mount | grep -q` can flake under pipefail (SIGPIPE)
is_mounted() { local m; m=$(mount); grep -qF " on $1 " <<<"$m"; }

mount_one() { # remote:path  mountpoint  volname
  mkdir -p "$2"
  local n
  n=$(pgrep -f "rclone nfsmount.*$2 " | wc -l | tr -d ' ' || true)
  # healthy = mounted AND exactly one daemon. Duplicate daemons share one VFS
  # cache dir and silently corrupt/stall uploads — treat as broken.
  if is_mounted "$2" && [ "${n:-0}" -eq 1 ] && ls "$2" >/dev/null 2>&1; then
    echo "$3 already mounted"; return
  fi
  echo "$3 not healthy (daemons=$n); remounting clean"
  # timeout guard (macOS has no timeout(1)): umount on a dead NFS mount can
  # hang forever, wedging the launchd agent and blocking future self-heals
  run_capped() { "$@" 2>/dev/null & local p=$!
    ( sleep 15; kill -9 "$p" 2>/dev/null ) & local w=$!
    wait "$p" 2>/dev/null; kill "$w" 2>/dev/null; }
  run_capped umount -f "$2"
  is_mounted "$2" && run_capped diskutil unmount force "$2"
  pkill -f "rclone nfsmount.*$2 " 2>/dev/null || true
  sleep 1
  # -o nobrowse: hide from Finder Locations/desktop — no "localhost", no eject;
  # the mountpoint behaves like a plain local folder.
  # vfs-cache-mode full: cache read data locally so repeat opens are instant
  # despite the transatlantic round-trip.
  rclone nfsmount "$1" "$2" \
    --volname "$3" \
    -o nobrowse \
    --vfs-cache-mode full \
    --vfs-cache-max-size 5G \
    --vfs-read-ahead 64M \
    --dir-cache-time 30s \
    --sftp-idle-timeout 0 \
    --timeout 30s --contimeout 15s --retries 3 \
    --log-file "/tmp/rclone-$3.log" --log-level INFO \
    --daemon
  echo "Mounted $3 at $2"
}

case "${1:-mount}" in
  configure) configure ;;
  mount)
    mount_one "cpx:$VPS_PATH" "$MNT_BASE/$VOL_VPS"  "$VOL_VPS"
    # NB: "sbox:" (login home), not "sbox:/" — the Storage Box chroot denies listing "/"
    mount_one "sbox:"                         "$MNT_BASE/$VOL_SBOX" "$VOL_SBOX"
    # No `open` here: the launchd agent re-runs this every 5 min and a Finder
    # window popping on each run steals focus. Open ~/Hetzner yourself.
    ;;
  unmount)
    umount "$MNT_BASE/$VOL_VPS"  2>/dev/null || true
    umount "$MNT_BASE/$VOL_SBOX" 2>/dev/null || true
    echo "Unmounted."
    ;;
  status)
    mount | grep -E "$VOL_VPS|$VOL_SBOX" || echo "Nothing mounted."
    ;;
  *) echo "usage: $0 {configure|mount|unmount|status}"; exit 1 ;;
esac
