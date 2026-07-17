# Miles' Infrastructure Repo

This repo is the source of truth for Miles' personal dev infrastructure:
runbooks, scripts, and a local HTML dashboard (`dashboard/index.html` — open it
in a browser; it's the human-facing overview of everything below).

## Current state (updated 2026-07-17)

**Goal:** cut fixed costs from ~$25/mo to ~$10/mo and cleanly split
compute/storage. Old CPX31 is being decommissioned.

| Machine | Details | Role |
|---|---|---|
| CX33 "cx33-server" | 89.167.110.196 · Helsinki · 4 vCPU/8GB/80GB | New primary dev server (fresh, not yet set up) |
| Storage Box "cold-storage" | u634219.your-storagebox.de · SFTP port 23 · BX11 1TB · Helsinki | Archives + hourly backup target |
| CPX31 | 5.78.108.176 · Hillsboro OR | OLD — migrate off, then delete (~$25/mo saved) |
| Modal | $30/mo free credits | Burst compute (`modal run`), never storage |
| Mac | client only | VS Code Remote-SSH, Mountain Duck, no vital data |

## Migration status / next actions

Follow `docs/migration-cpx31-to-cx33.md`. Interactive checklist lives in the
dashboard. As of last session NOTHING has been executed on real machines yet —
all scripts are written but unrun. Order:

1. CX33 first-boot hardening (runbook §"first-boot") + SSH keys everywhere
2. `tools/server/cpx31-audit.sh` on CPX31 → triage inventory (paste to Claude)
3. Snapshot CPX31 → rsync vital→CX33, rclone cold→Storage Box
4. Backup timer (`tools/server/hetzner-backup.*`) on CX33
5. ~~Finder mounts on Mac~~ DONE 2026-07-16 (rclone nfsmount + launchd, not Mountain Duck)
6. Cool-off week → delete CPX31
7. Pending separately: VS Code config review — run `tools/vscode-audit.sh` on
   the Mac and give the output to Claude to prune extensions for the 8GB box
8. Pending: iPhone file access via Secure ShellFish (SFTP into iOS Files app).
   When Miles installs it, add its public key to CX33 + Storage Box
   authorized_keys. iOS "Connect to Server" is SMB only, do not enable SMB.
9. Pending after migration: full Mac file system overhaul. Audit everything,
   delete aggressively (with approval), reorganize, move cold data to the
   Storage Box. Expect heavy use of ~/Hetzner/Storage.

## Key decisions already made (don't relitigate)

- Finder integration: **rclone nfsmount** (free, `tools/mac/`) — chosen
  2026-07-16 over Mountain Duck ($40) to avoid spend. Installed and working:
  `~/Hetzner/Server` (CX33) + `~/Hetzner/Storage` (box), mounted `nobrowse` so
  they behave like plain local folders (no localhost/eject in Finder); launchd
  agent auto-mounts at login and self-heals every 5 min. Full read caching
  (5G) hides the Helsinki latency. Mountain Duck remains the paid upgrade if
  cloud badges/offline-pinning are ever wanted. Use `nfsmount`, not `mount`.
- Backups: rclone hourly mirror now; upgrade path is BorgBackup (Storage Box
  supports it natively) if history/scale grows. No custom Rust sync — network-bound.
- Storage Box: SSH + External Reachability ON, SMB/WebDAV OFF, port 23.
- Secrets (future): Doppler for machine secrets, 1Password for human passwords.
- Heavy compute goes to Modal, not a bigger VPS. Hetzner rescale is the
  escape hatch (CPU/RAM-only resize is reversible; disk grow is not).

## Personal OS

The dashboard is not a project tracker: it is the standing source of truth,
always reflecting the latest state, and the first page of Miles' "Personal OS",
a family of pages sharing one brand (health and others will follow). The brand
lives in `brand/os.css` (tokens + components), `brand/README.md` (rules),
`brand/skeleton.html` (starter for new pages). Temporal work (like the CPX31
migration) appears as an "Active operation" section and is removed when done.
The "File and data principles" section carries the standing rules for all
development, personal and professional; the Mac file system scheme gets added
there after the post migration Mac overhaul.

## Conventions

- Repo: `milesdirmann/infra`, branch `main` (renamed 2026-07-16 from
  `milesdirmann/projects` / `claude/infrastructure-cost-optimization-vqmgse`).
  Local clone: `~/infra` on the Mac.
- Keep `dashboard/index.html` updated when fleet/config changes — it is the
  user's primary visual reference. Static values only; update "Last edit" date.
- Scripts must be idempotent and safe to re-run; comments carry install steps.
