# Hetzner drives in the macOS Finder sidebar

Two Finder locations, like Dropbox/Google Drive but self-hosted:

| Volume | Backed by | Use |
|---|---|---|
| **CPX-Projects** | VPS local NVMe (live code) | Drag files in/out of active projects |
| **Hetzner-Storage** | 1TB Storage Box (~€4/mo) | Archives, assets, backups |

Rename either by setting `VOL_VPS` / `VOL_SBOX` before mounting (e.g. `VOL_VPS=CPX31`).

## Step 0 — Buy the Storage Box (manual, ~2 min)

Hetzner Console → Storage Boxes → order **BX11 (1TB)**. Then in its settings
enable **SSH support**, and note the host (`uXXXXXX.your-storagebox.de`) and
username (`uXXXXXX`). Upload your key:

```bash
ssh-copy-id -p 23 uXXXXXX@uXXXXXX.your-storagebox.de
```

## Step 1 — Mac setup

### Option A (recommended): Mountain Duck — full Dropbox/Drive-style UX

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

### Option B (free fallback): rclone nfsmount

Plain Finder volumes — files stream on demand and never consume Mac disk, but
no badges or offline-pinning menu:

```bash
brew install rclone
# edit the 4 host/user lines at the top of tools/mac/mount-hetzner.sh, then:
bash tools/mac/mount-hetzner.sh configure
bash tools/mac/mount-hetzner.sh mount
```

A Finder window opens with both volumes — drag each into the sidebar once and
macOS keeps them pinned. Auto-mount at login: see the comment in
`tools/mac/com.hetzner.mounts.plist`.

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
- Don't point compilers/IDEs at the mounted volumes — that's what Remote-SSH
  is for. The mounts are for browsing and moving files.
- If Finder feels slow on huge directories, raise `--dir-cache-time`.
