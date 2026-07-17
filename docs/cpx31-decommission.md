# CPX31 decommission record

The CPX31 (5.78.108.176, Hillsboro OR, 4 vCPU / 8 GB / 150 GB) was the last
US box. This is the permanent record of what lived on it, where each piece
went, and what died with it. Written 2026-07-17, the day it was emptied.

Archive root: `sbox:archive/cpx31` on the Storage Box (browse it at
`~/Hetzner/Storage/archive/cpx31` in the Finder).

## What it actually was, at the end

118 GB used of 150 GB. Despite appearances, **nothing on it was serving
live traffic**. Verified, not assumed:

| Thing | State when audited |
|---|---|
| ClickHouse (48 GB on disk) | Stopped. Had been for a while. |
| Redis | Running, empty. Zero keys. |
| Postiz | Containers gone. Only its 133 MB of volumes remained. |
| `api.scouq.com` | DNS pointed here, returned **502**. Backends (8084, 8082, 18123) all dead. |
| `post.avogrowth.com` | Proxied here through Cloudflare, returned **502**. Port 3000 dead. |
| `liquidco-engine` | Running, but erroring every 60 s. Stale deploy from 2026-07-08. |
| `codex-app-server-avo` | Running. Mobile remote sessions for Avo, which is being reset anyway. |
| `avo-action-ingest` | Crash looping (stuck "activating"). |
| Apollo cron ingesters | Firing on schedule, writing into a **stopped** ClickHouse. |

The lesson worth keeping: the box looked busy (14 services, nginx, cron) and
was in fact inert. Audit before believing.

## The one irreplaceable thing

`/home/liquidco/engine/engine.db`, 123 MB of SQLite: **255,790 tracked
listings**, 17,213 inferred sales, 35,860 jobs, 2,745 product identities.
This is the LiquidCo bid history corpus, accumulated over months. The Mac's
`gold-scanner` repo has newer *code* (committed 2026-07-16) but an empty
`db/`, so this file was the only copy of the data anywhere.

It was live and being written during the migration, so a plain file copy
risked a torn database. It was captured with SQLite's online backup API
(`.backup`), `PRAGMA integrity_check` returned `ok`, and all row counts
matched the live database. Now in three places, identical sha256
(`1f0f1569...c50a11`):

- `sbox:archive/cpx31/db-dumps/liquidco-engine.db`
- `CX33:/root/projects/cpx31-imports/liquidco-engine.db`
- (source, destroyed with the server)

**If you ever resume the gold engine: deploy the code from the Mac's
`gold-scanner` repo, then point it at this database.** Do not resurrect the
server's stale `dist/`.

## Where everything went

| Data | Destination |
|---|---|
| ClickHouse 48 GB (`alien` + `scouq` dbs) | `archive/cpx31/clickhouse.tar.zst`, 31 GB compressed, sha256 verified end to end |
| `/home/avo` 27 GB (minus venvs, node_modules, caches, whisper models) | `archive/cpx31/home/avo`, checksum verified |
| `/home/scouq`, `/home/liquidco`, `/home/gold`, `/home/invest` | `archive/cpx31/home/...` |
| `/root/argus-source`, `argus-leads`, `argus-bin`, `avo-project` | `archive/cpx31/root/...` |
| nginx, letsencrypt, systemd units, all crontabs, docker volumes (postiz), redis dump, dpkg selections | `archive/cpx31/system-bundle.tar.zst` |
| LiquidCo engine database | `archive/cpx31/db-dumps/` + CX33 (see above) |
| `liquidco`, `gold`, `invest` code (possibly still wanted) | `CX33:/root/projects/cpx31-imports/` |
| node_modules, .venv, caches, whisper models, OS | Nowhere. Regenerable by design. |

Whisper models were excluded deliberately: `ggml-large-v3.bin` (2.9 GB) and
`ggml-small.en.bin` (466 MB) are free re-downloads from Hugging Face.

## Git repos

Every repo was archived with its full `.git` directory, so history is
preserved even where it was never pushed. The ones that had work only on
this machine, at archive time:

| Repo | Uncommitted | Unpushed commits |
|---|---|---|
| `/home/avo/site` | 29 | **306** |
| `/home/avo/email` | 2653 | 7 |
| `/home/avo/tools` | 1106 | 1 |
| `/home/avo/dashboard` | 3 | 4 |
| `/home/avo/embed` | 10 | 2 |
| `/home/avo/service/email-tools` | 1 | 2 |
| `/home/avo/project/avo` | 15 | 0 |
| `/home/avo/ch-proxy` | 2 | 1 |
| `redis-proxy`, `leads`, `glossary`, `notifications`, `atlas/*` | 0 | 1 each |

These were **not** pushed to GitHub during the migration. That was a
deliberate hold: Avo is being rebuilt from scratch (the 16 K leads and 35
callers were faulty), so publishing 306 commits of that era to GitHub is a
judgment call, not a mechanical step. The history is safe in the archive if
it is ever wanted.

## DNS left dangling

Two records pointed at 5.78.108.176 and **must not outlive the server**. A
record aimed at a released Hetzner IP is a subdomain takeover risk: whoever
gets that IP next inherits the hostname.

| Record | Zone | Status |
|---|---|---|
| `api.scouq.com` A | scouq.com (Cloudflare) | Must be deleted. The `CLOUDFLARE_API_TOKEN` on the CPX31 only scopes to avogrowth.com, so this one needs the dashboard. |
| `post.avogrowth.com` A (proxied) | avogrowth.com (Cloudflare, zone `45c8ab7f...`) | Must be deleted. Reachable with the existing token. |

Both were already returning 502 before the migration, so removing them
breaks nothing that worked.

## Why no cool off week

The runbook originally called for a week of working off the new box before
deleting. That was written before the audit. Since nothing on the CPX31
serves traffic, nothing points at it that is not already broken, and the
data is verified in Helsinki, a cool off week only delays the saving. The
Hetzner snapshot is the real safety net, and it is kept for two weeks after
deletion.
