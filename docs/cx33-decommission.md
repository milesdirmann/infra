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

## Steps left for Miles (nothing on the server needs saving first)

1. **Set the backup secret**, then run the workflow once to prove it:
   ```
   ssh server 'set -a; . /root/.tabernacle-db.env; printf %s "$DATABASE_URL"' | gh secret set DATABASE_URL --repo milesdirmann/tabernacle
   gh workflow run db-backup.yml --repo milesdirmann/tabernacle
   ```
   (Run it yourself: the connection string carries the DB password and was
   deliberately not moved by an agent.) Until it is set, the nightly run fails
   with a clear message and GitHub emails you.
2. **Cloudflare DNS:** delete the A records pointing at `89.167.110.196`
   (`db.ophiri.com`, `api.scouq.com`, and any others). A freed Hetzner IP gets
   reassigned, and a dangling record would point your hostname at a stranger.
3. **Mac:** remove `Host server` from `~/.ssh/config`; drop the `Server` volume
   from `tools/mac/mount-hetzner.sh` (the same launchd job also mounts the
   Storage Box, so do not unload it); `git remote remove cx33` in
   `~/Tabernacle/app` and `~/Tabernacle/tabernacle-os-github`, and
   `cx33site-retired` in `~/Tabernacle`.
4. **Hetzner console:** optional final snapshot, then delete `cx33-server`.
   The hourly Storage Box backup and the dashboard page generator run on that
   box and end with it.

## Things worth knowing

- CI now uses GitHub-hosted minutes. The old workflow comment said the
  self-hosted runner existed to avoid metered minutes; a full run is about
  5 minutes, so watch the private-repo allowance if push volume is high.
- `~/scouq-brain` now has an off-Mac replica: private `github.com/Scouq/scouq-brain`,
  created 2026-10-11 by the Scouq product session with Miles's go (verified: it
  exists, is private, holds branch `codex/brain-reconciliation-2026-10-09`). Still
  pending Miles: confirm keeping it and set the default branch. The CX33 Git
  replicas (`/srv/scouq/repos/scouq-brain.git`, `scouq-app.git`) are then redundant.
- Storage Box: holds ~52 GiB that exists nowhere else (archive/cpx31 44.1 GiB,
  Scriptura 0.70 GiB, cx33-final 1.4 GiB, backups 5.1 GiB). Do not cancel it
  until Miles decides where long-term archives go.
