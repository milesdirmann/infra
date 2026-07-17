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
5. Mountain Duck bookmarks (docs/finder-remote-volumes.md — Option A) on Mac
6. Cool-off week → delete CPX31
7. Pending separately: VS Code config review — run `tools/vscode-audit.sh` on
   the Mac and give the output to Claude to prune extensions for the 8GB box

## Key decisions already made (don't relitigate)

- Finder integration: **Mountain Duck** (File Provider: cloud badges,
  online-only files) over rclone mounts; rclone nfsmount kit kept as free
  fallback in `tools/mac/`. Homebrew's macOS rclone has no `mount` — use `nfsmount`.
- Backups: rclone hourly mirror now; upgrade path is BorgBackup (Storage Box
  supports it natively) if history/scale grows. No custom Rust sync — network-bound.
- Storage Box: SSH + External Reachability ON, SMB/WebDAV OFF, port 23.
- Secrets (future): Doppler for machine secrets, 1Password for human passwords.
- Heavy compute goes to Modal, not a bigger VPS. Hetzner rescale is the
  escape hatch (CPU/RAM-only resize is reversible; disk grow is not).

## Conventions

- Branch for this work: `claude/infrastructure-cost-optimization-vqmgse`
- Keep `dashboard/index.html` updated when fleet/config changes — it is the
  user's primary visual reference. Static values only; update "Last edit" date.
- Scripts must be idempotent and safe to re-run; comments carry install steps.
