# Handoff for Codex: CX33 retirement + what Scouq is and is not

Written 2026-10-10 by Claude Code for Miles' Codex agent(s). Read this whole file
before acting. Miles' standing rule applies throughout: **never delete anything
without asking him first.**

## 1. What Scouq is (and the only thing it is)

Scouq is a **done-for-you, productized AI sales agent service** for B2B service
businesses that sell over booked calls. Miles set this on 2026-09-28 ("going all
in on this... not changing my mind"). The Brain is the source of truth for
everything that changes (offer, price, voice stack, priorities):

1. `cd ~/scouq-brain && brain pull && brain check` (if the CLI exists)
2. read `status.md` first, then `README.md`, `PROTOCOL.md`, `governance/agent-rules.md`
3. if anything on disk, in memory, or in your recollection disagrees with the Brain, the Brain wins

Do not copy offer, price, or stack facts into this file or any agent startup file.

### Everything below is ARCHIVED HISTORY, not Scouq

Do not build on it, resume it, quote its prices or plans, or treat its "current" or
"final" wording as true. Use it only if Miles names the specific asset.

- real-estate data platform (parcels, ClickHouse, ATTOM, skip tracing, `/home/scouq`)
- church ministry platform (also: Memphis Tabernacle / Tabernacle OS is a separate
  project and has never been part of Scouq)
- operational-systems consultancy; business-improvement app; adaptive advisor
- AI accounting / bookkeeping company
- Scouq OS growth operating system
- recurring-revenue platform (frozen)
- 2026-09-25 done-for-you growth company (roofing first) and the 2026-09-26
  business-systems-integration / dealership-audit positioning
- free lead-magnet app

`~/scouq-brain/archive/INDEX.md` classifies each of these. Avo (avogrowth.com, Avo
Mail) is a different business; `~/scouq-site` is Avo-owned code despite its name.

## 2. What you may touch

| Area | Rule |
|---|---|
| `~/scouq-com` and its `~/scouq-com-*` / `~/scouq-com-wt-*` worktrees (about 85, branches dated 2026-10-01 to 10-10) | **Current.** These are live feature worktrees of the current product, not leftovers. Work in them per your task. Many local branches are not on any remote (about 420 commits by `git log --branches --not --remotes`): push or confirm before anyone removes a worktree. |
| `~/scouq-brain` (branch `codex/brain-reconciliation-2026-10-09` was active 2026-10-10) | Current. Edit only through the conflict protocol in `PROTOCOL.md` (flag to Miles, then edit, `brain bump`, `brain log`, commit). Another Codex session is committing here, so check `git log` first and do not fork the branch. |
| `~/scouq-livekit-spike`, `~/scouq-livekit-calling-worker` | Current voice work (LiveKit + Telnyx per the Brain). |
| `~/scouq-leads`, `~/scouq-com-*` docs | Prospect lists: confirm with Miles which are still used before changing. |
| `~/infra` | Infra repo. Update `docs/` and `dashboard/index.html` when fleet or config changes. |
| **Read only unless Miles names the asset:** `~/Scouq`, `~/scouq-site`, `~/scouq-web`, `~/scouq-studio`, `~/Scouq-roofing-site`, `~/scouq-coach`, `~/scouq-research`, `~/scouq-canary`, `~/scouq-voice-spike`, `~/scouq-backups`, Dropbox `Scouq/`, `~/Documents/Scouq*`, `~/Documents/scouq-app-captures` | Old directions or experiments. Never build on them. |
| `~/Tabernacle/**` | Separate project (see section 4). Not Scouq. |

## 3. Cleanup of the old Scouq material (proposal, nothing deleted yet)

Miles wants a lot of the old Scouq material gone so agents stop getting confused.
That is a decision for him, item by item. Suggested process:

1. For each candidate, report size, last commit, dirty files, and unpushed commits.
2. Anything with unpushed commits or uncommitted changes is archived first to
   `sbox:archive/<name>-<date>/` (Storage Box, verify with `rclone check`), then
   Miles approves deletion by name.
3. Never delete a `~/scouq-com-*` worktree or the Brain as part of this.

Measured 2026-10-10 (size / last commit / dirty files / unpushed commits):

| Candidate | Size | Last | Dirty | Unpushed | Note |
|---|---|---|---|---|---|
| `~/Scouq` (old app: Scouq OS, accounting, platform) | 12G | 2026-09-23 | 10 | 49 | frozen; keep `brand/` (still current brand source) and extract before removal |
| `~/scouq-site` | 1.6G | 2026-07-28 | 2 | 326 | Avo-owned; belongs in Avo's archive, not Scouq |
| `~/scouq-web` | 1.1G | 2026-08-15 | 0 | 26 | tailark template era |
| `~/scouq-studio` | 2.2G | 2026-09-26 | 0 | 5 | |
| `~/Scouq-roofing-site` | 3.5G | 2026-09-26 | 29 | 6 | 09-25 growth-company era; check the docs inside before archiving |
| `~/scouq-voice-spike`, `~/scouq-coach`, `~/scouq-research`, `~/scouq-canary`, `~/scouq-backups` | small | n/a | n/a | n/a | not git; look before deciding |
| Dropbox `Scouq/` top-level design docs, `Scouq/Brain` mirror, `~/Documents/Scouq`, `~/Documents/Scouq App` | not measured | | | | listed as stale in the Brain archive index |

## 4. Instruction files that are currently wrong (fix, do not follow)

- `~/scouq-brain/archive/INDEX.md` still says the current business is the
  2026-09-25 growth company and does not list 2026-09-28. `status.md` is correct.
  Fix it on the Brain branch via the conflict protocol; add rows for the 09-25
  growth company and the 09-26 integration/dealership direction as archived.
- `~/.codex/AGENTS.md` names the "CPX31 server copy" `/home/scouq/scouq-brain`.
  CPX31 is archived. Remove that line and say the Mac Brain is the only copy.
- `~/AGENTS.md` and `~/CLAUDE.md` infra sections are stale (CX33 "hosts Scriptura",
  CPX31 as primary). `~/infra` wins; update after step 5 below.
- Brain `engineering.md`, `platform-map.md`, `infrastructure.md` mention the CX33
  Git replicas and `api.scouq.com` "mis-pointing at CX33". Update once the CX33 is gone.

## 5. CX33 retirement (Hetzner server 89.167.110.196)

Miles decided it is not needed. Full record: `~/infra/docs/cx33-decommission.md`.

Done 2026-10-09/10: Tabernacle site moved to GitHub `milesdirmann/tabernacle-workspace`
with Vercel auto-deploy (`tabernacle-mock`) and a scheduled watch-sync Action; CI for
`milesdirmann/tabernacle` moved to GitHub-hosted runners (PRs 183, 184); nightly
Supabase dump moved to `db-backup.yml` (secret set by Miles, first run succeeded, 11.5 MB);
final archive at `sbox:archive/cx33-final-2026-10-09/` (verified); Ophiri, Nango, Dropbox
mount, `scouq-api` retired.

**Open item you must raise with Miles before the server is deleted:** the Brain
(`engineering.md`) records Git replicas on the CX33 (`/srv/scouq/repos/scouq-brain.git`
and `scouq-app.git`, Mac remote `cx33`). `github.com/Scouq/scouq-brain` returns "not
found", so the Brain's only off-Mac live replica is the CX33. A snapshot is in the
final archive and the hourly mirror, but nothing will keep it current after deletion.
Ask Miles where the Brain should be replicated (private repo under `milesdirmann`, or
the Storage Box), then update `engineering.md` and remove the `cx33` remote.

Steps left for **Miles** (do not do these for him): delete the Cloudflare A records
for `89.167.110.196` (`db.ophiri.com`, `api.scouq.com`); drop `Host server` from
`~/.ssh/config` and the `Server` volume in `~/infra/tools/mac/mount-hetzner.sh`
(the same launchd job also mounts the Storage Box, so do not unload it); remove the
`cx33` git remotes; delete `cx33-server` in the Hetzner console.

## 6. Do / do not

- Do read the Brain first and report conflicts to Miles instead of silently choosing.
- Do keep `~/infra/dashboard/index.html` and `docs/` truthful when fleet state changes.
- Do not delete, archive-then-delete, or force-push anything without Miles naming it.
- Do not treat Codex or Claude memory as business truth; use it only to find files.
- Do not paste secrets into files, chat, or commit messages. Doppler and Vercel hold them.
