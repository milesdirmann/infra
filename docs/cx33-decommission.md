# CX33 decommission

Written 2026-10-09. Miles decided the CX33 is no longer needed: the businesses
in focus are Scouq and Tabernacle, and neither needs this box.

## What was on it, and where it lives now

| Was on the CX33 | Now |
|---|---|
| Tabernacle site (`/srv/git/tabernacle-site.git`, deployed to the `tabernacle-mock` Vercel project) | GitHub `milesdirmann/tabernacle-workspace` (private, `main`), with the server's 34 watch-sync commits merged. Vercel project connected to it with root directory `site`; every push to `main` deploys. |
| Watch-sync timer (`watch-sync.timer`, 23:30 UTC) | `.github/workflows/watch-sync.yml` in that repo, same schedule, commits as the account owner (Vercel Hobby blocks other authors). Tested: scrape works from GitHub runners. |
| Self-hosted CI runner for `milesdirmann/tabernacle` | Both CI jobs run on `ubuntu-latest` (PR 183, merged). pgTAP job installs PostgreSQL 17 + pgTAP from PGDG each run. Runner registration deleted. |
| Nightly Supabase `pg_dump` (`tabernacle-db-backup.timer`) | `.github/workflows/db-backup.yml` in `milesdirmann/tabernacle`, 08:30 UTC, 90-day artifact. **Needs the `DATABASE_URL` secret, see step 1.** Existing 60 days of dumps stay on the Storage Box (`backups/tabernacle-db`). |
| Tabernacle member app on `:8081` | Unused (0 requests in 7 days). Source is on GitHub (`tabernacle-app`), nothing unique on the server. |
| `memphis-disc-assessment` / `memphis-building-finance` worktrees | All branches already on GitHub (checked by commit). One untracked spec file existed only there; it is in the archive below. |
| Ophiri (DB, scanner, `db.ophiri.com`) | Retired. Jobs stopped 2026-10-08. DB dumps + archive on the Storage Box (`backups/ophiri-archive`), code in the final archive. |
| Nango, Dropbox mount, `scouq-api`, `api.scouq.com` placeholder | Retired. Nango secrets archived 2026-08-14. No Vercel env var or code in `scouq-com` references any of them (checked). |
| Old Scouq worktrees (`/srv/scouq`) | Archived history, tarball in the final archive. `~/scouq-brain` on the Mac holds everything the server copy had. |

## Final archive

`sbox:archive/cx33-final-2026-10-09/`, verified with `rclone check`:
`server-state/` (server-config.tgz of Caddy/systemd/ufw/cron/local scripts,
home-ophiri-app.tgz, srv-scouq-no-secrets.tgz, unit and docker lists),
`root-documents-codex/`, `root-dot-claude/`, `root-dot-codex/` (auth.json excluded).
Also already on the box: `backups/srv`, `backups/tabernacle-db`,
`backups/ophiri-archive`, `archive/scriptura-retired-2026-08-14`,
`archive/nango-secrets-2026-08-14`, `cpx31/`.

## Storage Box contents copied to the Mac (2026-10-11/12)

`~/Archive/hetzner-2026-10/` (18 GiB, 36,828 files, `SHA256SUMS.txt`; every
folder size-checked against the box with `rclone check`, the CPX31 tarballs
re-checked against their original sha256s). Contains `archive/` (cpx31,
cx33-final-2026-10-09, scriptura-retired-2026-08-14, scouq), `backups/`
(ophiri-archive, projects, tabernacle-db) and `extra-from-cx33/` (13 verified
git bundles of the retired Scouq and Tabernacle repos, `loose/` spec file,
agent-handoffs, Nango compose without secrets).
Deliberately NOT copied, per Miles: `archive/cpx31/clickhouse.tar.zst` (33.7 GiB
old ClickHouse real-estate + Avo email data), `archive/nango-secrets-2026-08-14`
(Nango is unused), `backups/.trash`, `backups/srv` (the CX33 `/srv` mirror,
already captured in cx33-final). Those exist only on the Storage Box until it is
cancelled. Scriptura also lives in private `github.com/milesdirmann/scriptura`
(history scanned for secrets first). There is no second copy of the archive off
the Mac (Miles: "idk"); GitHub already holds everything that is live.

## Mac cleanup, done 2026-10-12

`Host server` removed from `~/.ssh/config` (backup `config.bak-2026-10-12-cx33`);
`cx33` git remotes removed from `~/Tabernacle`, `~/Tabernacle/app` and
`~/Tabernacle/tabernacle-os-github`; the `scriptural` checkout now points at the new
GitHub repo; the Finder mounts are stopped and `com.hetzner.mounts.plist` is moved to
`~/Library/LaunchAgents/_disabled/`. `tools/mac/mount-hetzner.sh` is kept only as
history. `~/.config/rclone/rclone.conf` still holds the `sbox` and `cpx` remotes;
delete them after the Storage Box is cancelled.

## New blocker found 2026-10-15: Tabernacle Google Ads work runs on the CX33

Seven read-only Ads scripts in `/srv/tabernacle-growth/` (written 2026-10-07 to 10-12, three of
them after the final archive) use the `google-ads` MCP server configured in
`/root/.codex/config.toml` (edited 2026-10-12). The Mac's `~/.codex/config.toml` has no such
entry. Scripts are copied to `~/Archive/hetzner-2026-10/extra-from-cx33/tabernacle-growth/`.
The MCP credentials were deliberately not copied; before the server goes, either set the
google-ads MCP up in the Mac Codex config (Miles' call, it moves credentials) or accept that
the Ads tooling stops. A Codex process (since Aug 15) and `claude agents` (since Aug 29) are also
still running on the box; their session history is in `/root/.codex` (archived 2026-10-09).

## Server deleted 2026-10-15

Miles deleted `cx33-server` in the Hetzner console (IPv4/IPv6 not kept). SSH to
`89.167.110.196` now times out. A last-minute sweep (before the delete) saved
`/root/.codex/config.toml` (holds the Google Ads MCP credentials, mode 600), `/root/.claude`,
and `/srv/tabernacle-growth` to
`~/Archive/hetzner-2026-10/extra-from-cx33/final-sweep-2026-10-15/`. The Codex session history
copy there is partial (about 92 MB; the connection dropped mid-copy); the fuller 2026-10-09
copy is in `archive/cx33-final-2026-10-09/root-dot-codex`.

## Steps left for Miles

1. **Cloudflare DNS:** delete the A records that still point at `89.167.110.196`
   (`db.ophiri.com`, `api.scouq.com`, any others). The IP can now be reassigned to a stranger.
2. **Hetzner console:** cancel the Storage Box (`u634219`). Afterwards the ClickHouse dump and
   `backups/srv` are gone for good; everything else is in `~/Archive/hetzner-2026-10`.
3. **Google Ads tooling:** decide whether to set up the `google-ads` MCP in the Mac Codex config
   (the saved `codex-config.toml` has what it needs) or let it go.
4. After the box is cancelled: delete the `sbox` and `cpx` remotes from `~/.config/rclone/rclone.conf`.

## Things worth knowing

- CI now uses GitHub-hosted minutes. The old workflow comment said the
  self-hosted runner existed to avoid metered minutes; a full run is about
  5 minutes, so watch the private-repo allowance if push volume is high.
- `~/scouq-brain` now has an off-Mac replica: private `github.com/Scouq/scouq-brain`,
  created 2026-10-11 by the Scouq product session with Miles's go (verified: it
  exists, is private, holds branch `codex/brain-reconciliation-2026-10-09`). Still
  pending Miles: confirm keeping it and set the default branch. The CX33 Git
  replicas (`/srv/scouq/repos/scouq-brain.git`, `scouq-app.git`) are then redundant.
