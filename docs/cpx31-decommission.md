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

Archive total: **50.4 GiB**. Every stream was sha256'd on the CPX31 as it was
written and independently re-hashed on the Storage Box afterwards. All nine
matched. Full list in `archive/cpx31/MANIFEST.txt`.

| Data | Archive | Size | sha256 |
|---|---|---|---|
| ClickHouse 48 GB (`alien` + `scouq`), server stopped so the copy is consistent | `clickhouse.tar.zst` | 33.7 GB | `2a73b741` |
| `/home/avo`, 139,302 files | `home-avo.tar.zst` | 8.06 GB | `acc125eb` |
| `/home/scouq`, 129,467 files | `home-scouq.tar.zst` | 3.79 GB | `df05aa25` |
| `/root`: argus-source, argus-leads, argus-bin, avo-project | `root-work.tar.zst` | 138 MB | `d868ac8a` |
| `/home/liquidco` incl. engine.db | `home-liquidco.tar.zst` | 24 MB | `8c42f4bf` |
| nginx, letsencrypt certs, systemd units, all crontabs, docker volumes (postiz postgres), redis dump, dpkg selections, `avo/.env` | `system-bundle.tar.zst` | 18 MB (132 MB raw) | `c4e80373` |
| `/home/gold` | `home-gold.tar.zst` | 1.6 MB | `6873c6c3` |
| `/home/invest` | `home-invest.tar.zst` | 20 KB | `01ba4a05` |
| LiquidCo bid history, SQLite `.backup` | `db-dumps/liquidco-engine-final.db` | 128 MB | `1f0f1569` |
| Loose 1 GB dataset from `/tmp` | `stray/redfin_city.gz` | 1 GB | n/a |
| `liquidco`, `gold`, `invest` code + the engine db | also on `CX33:/root/projects/cpx31-imports/` | 350 MB | |
| node_modules, .venv, caches, whisper models, OS | Nowhere. Regenerable by design. | | |

Verification was not left at "the hashes match". The LiquidCo database was
pulled back **out** of `home-liquidco.tar.zst` on the Storage Box, extracted,
and opened: `PRAGMA integrity_check` returned `ok` and all 255,790 rows were
there. The archive is not just intact, it is usable.

Whisper models were excluded deliberately: `ggml-large-v3.bin` (2.9 GB) and
`ggml-small.en.bin` (466 MB) are free re-downloads from Hugging Face.

### Reading the archive

Each tree is one `.tar.zst` stream (not a browsable directory) because the
box is 150 ms away and per-file SFTP on 278,000 files would have taken about
eleven hours instead of one. To compensate, `archive/cpx31/filelists/` holds
a `size / date / path` index of every file, so the archive is searchable
without extracting anything:

```bash
grep -i somefile ~/Hetzner/Storage/archive/cpx31/filelists/home-avo.filelist.txt
# extract a single path without unpacking the whole tar:
rclone cat sbox:archive/cpx31/home-avo.tar.zst | zstd -d | tar -xf - path/inside
```

Caveat: the filelists record what was **on the server**, so they include the
whisper models and other excluded junk that is deliberately **not** inside
the tars. The filelist is the inventory, the tar is the archive.

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
