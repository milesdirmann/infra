#!/usr/bin/env bash
# Mount Hetzner locations as Finder volumes via rclone nfsmount (no FUSE needed).
# NOTE: this is the FREE fallback. For Dropbox-style Finder integration
# (cloud badges, online-only files, right-click offline pinning) use
# Mountain Duck instead — see docs/finder-remote-volumes.md.
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
# -----------------------------------------------------------

VOL_VPS="${VOL_VPS:-CX33-Projects}"     # Finder sidebar name for live VPS projects
VOL_SBOX="${VOL_SBOX:-Cold-Storage}"    # Finder sidebar name for the 1TB Storage Box
MNT_BASE="$HOME/HetznerDrives"

configure() {
  rclone config create cpx sftp host "$VPS_HOST" user "$VPS_USER" key_file "$HOME/.ssh/id_ed25519"
  # Storage Box speaks SFTP on port 23
  rclone config create sbox sftp host "$SBOX_HOST" user "$SBOX_USER" port 23 key_file "$HOME/.ssh/id_ed25519"
  echo "Remotes written. Test with: rclone lsd cpx: && rclone lsd sbox:"
}

is_mounted() { mount | grep -qF " on $1 "; }

mount_one() { # remote:path  mountpoint  volname
  mkdir -p "$2"
  if is_mounted "$2"; then
    # verify the mount is actually alive, not a stale handle from sleep/wake
    if ls "$2" >/dev/null 2>&1; then echo "$3 already mounted"; return; fi
    echo "$3 mount is stale; remounting"
    umount -f "$2" 2>/dev/null || diskutil unmount force "$2" 2>/dev/null || true
  fi
  rclone nfsmount "$1" "$2" \
    --volname "$3" \
    --vfs-cache-mode writes \
    --vfs-cache-max-size 2G \
    --dir-cache-time 30s \
    --sftp-idle-timeout 0 \
    --timeout 30s --contimeout 15s --retries 3 \
    --daemon
  echo "Mounted $3 at $2"
}

case "${1:-mount}" in
  configure) configure ;;
  mount)
    mount_one "cpx:/home/$VPS_USER/projects" "$MNT_BASE/$VOL_VPS"  "$VOL_VPS"
    mount_one "sbox:/"                        "$MNT_BASE/$VOL_SBOX" "$VOL_SBOX"
    open "$MNT_BASE"   # drag the two volumes into the Finder sidebar once; macOS remembers
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
