# Hetzner drives in the macOS Finder sidebar

Two plain folders under `~/Hetzner/`, like Dropbox/Google Drive but self-hosted:

| Folder | Backed by | Use |
|---|---|---|
| **~/Hetzner/Server** | CX33 NVMe, `/root/projects` (live code) | Drag files in/out of active projects |
| **~/Hetzner/Storage** | 1TB Storage Box (~€4/mo) | Archives, assets, backups |

Mounted with `nobrowse`, so nothing shows under Finder's Locations — no
"localhost" host entry, no eject buttons, no "Connected as: NFS" banner. They
look and act like normal local folders. Rename by setting `VOL_VPS` /
`VOL_SBOX` before mounting.

## Step 0 — Buy the Storage Box (manual, ~2 min)

Hetzner Console → Storage Boxes → order **BX11 (1TB)**. Then in its settings
enable **SSH support**, and note the host (`uXXXXXX.your-storagebox.de`) and
username (`uXXXXXX`). Upload your key:

```bash
ssh-copy-id -p 23 uXXXXXX@uXXXXXX.your-storagebox.de
```

## Step 1 — Mac setup

### Option A (CHOSEN 2026-07-16, free): rclone nfsmount

Plain folders — files stream on demand with a 5G local read cache (repeat
opens are instant), but no cloud badges or offline-pinning menu. Installed
and verified on Miles' Mac:

```bash
brew install rclone
bash tools/mac/mount-hetzner.sh configure   # writes cpx: + sbox: remotes
bash tools/mac/mount-hetzner.sh mount       # mounts both under ~/Hetzner
```

A Finder window opens at ~/Hetzner — drag Server/Storage (or the ~/Hetzner
parent) into the sidebar Favorites once and macOS keeps them pinned.
Auto-mount at login is installed via
`~/Library/LaunchAgents/com.hetzner.mounts.plist` (re-checks every 5 min,
self-heals dropped mounts after sleep/wake).

### Option B (paid upgrade, skipped for now): Mountain Duck — full Dropbox/Drive-style UX

The cloud badges, per-file download buttons, and right-click
"Make available offline" / "online only" menus are Apple File Provider
features; only File Provider apps can show them. Mountain Duck
(mountainduck.io, ~$40 one-time, free trial) does this over plain SFTP:

```bash
brew install --cask mountain-duck
```

Add two bookmarks (File > New Bookmark), each with **Smart Synchronization**
enabled (the default):

| Bookmark | Protocol | Server | Port | User | Path |
|---|---|---|---|---|---|
| CX33 | SFTP | 89.167.110.196 | 22 | root | /root/projects |
| Cold-Storage | SFTP | u634219.your-storagebox.de | **23** | u634219 | / |

Use your SSH key for auth on both. Both appear under Finder's Locations with
cloud icons: files are online-only by default (zero Mac disk), click/open to
download, right-click for Keep Offline / Remove Local Copy.

## Step 2 — VPS one-time setup (backup mirror)

Follow the comments in `tools/server/rclone-backup.sh`. Result: every hour the
VPS quietly mirrors `~/projects` to the Storage Box, keeping deleted/changed
files in dated `.trash/` folders so a bad sync never destroys history.

## "Download button" semantics

A mounted volume already behaves like Drive's download: files stream on open,
and **drag-and-drop to your Desktop = download** (Finder copies from remote to
local). Nothing is stored on the Mac except a small write cache. If you later
want true Dropbox-style per-file "Download / Remove local copy" buttons and
online-only placeholder files, that's Apple's File Provider API — buy
**Mountain Duck** (~$40 once) and point it at the same two SFTP endpoints; it
replaces Step 1 with zero scripts.

## Gotchas

- Storage Box SFTP runs on **port 23**, not 22.
- Storage Box paths must be **home-relative** (`sbox:`), never absolute
  (`sbox:/`) — the chroot denies listing `/` (found the hard way 2026-07-16).
- On the CX33 the projects dir is `/root/projects` (root's home is `/root`,
  not `/home/root`).
- Don't point compilers/IDEs at the mounted volumes — that's what Remote-SSH
  is for. The mounts are for browsing and moving files.
- If Finder feels slow on huge directories, raise `--dir-cache-time`.
