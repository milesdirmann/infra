# Project System: structure, context files, storage contract, automation

Date: 2026-07-19. Status: approved by Miles, pending spec review.
Owner: Miles Dirmann. Applies to: CX33 server, infra repo, all future projects.

## Purpose

One system that makes every project legible to agents and humans from any
device. Fixes: agents starting cold, dated status information, storage mess,
no convention for new projects. Must scale to more and bigger projects
without degrading.

## Decisions locked during design

1. Server-first: every project lives on the CX33. Mac and iPhone are windows
   (VS Code Remote, Files app). Nothing vital on the Mac.
2. Tracking: files in each repo plus one generated overview page in the
   Personal OS brand. No external service.
3. Instruction files: AGENTS.md is canonical and model agnostic. CLAUDE.md is
   a two line router pointing at it. Same pattern globally and per project.
4. Anti rot: machine derived facts are generated and cannot lie. Agents write
   only narrative. Staleness is surfaced, never silent.

## Layout

```
/root/AGENTS.md              global canonical: durable preferences and rules
/root/.claude/CLAUDE.md      global router to the above
/root/projects/<name>/       every project, one directory
  AGENTS.md                  durable: what, stack, conventions, boundaries, storage block
  CLAUDE.md                  router, two lines, never changes
  STATUS.md                  volatile: now, next, decisions, blocked
/srv/git/<app>.git           bare repos for deployed apps (existing Scriptura pattern)
/srv/<app>                   deployed checkouts behind Caddy
```

Sessions always start inside the project directory, in a tmux session named
after the project: `ssh server -t tmux new -A -s <name>` then cd and run the
agent. The scaffold ships a helper `p <name>` that does all three.

## Storage contract (four tiers)

| Tier | Location | Holds | Backed up |
|---|---|---|---|
| Code | GitHub | all source | inherently |
| Hot | CX33 /root/projects and /srv | working trees, services, active data | hourly rclone to box |
| Cold | Storage Box datasets/ and archive/ | large data, retired projects | is the backup |
| Ephemeral | anywhere | caches, node_modules, build output | never, excluded |

Rules an agent applies without judgment calls:

- Regenerable: exclude from backup, keep nowhere.
- Active and under a few GB: hot.
- Large or dormant: cold, streamed on demand via rclone.
- Code: pushed to GitHub, always.
- Databases: every project that declares one dumps to
  `<project>/data/dumps/` on a timer. The hourly backup then covers all
  databases by construction. No per database backup paths.
- Archives: tar plus zstd level 3, sha256 recorded, filelist index written.
  Named `<name>-YYYY-MM-DD.tar.zst`. Same pattern as the verified CPX31
  archive.

Each AGENTS.md carries a storage block:

```yaml
storage:
  hot_budget: 2GB
  cold: sbox:datasets/<name>    # only if large data exists
  database: none | postgres | sqlite
  deploy: none | srv
```

## File formats

AGENTS.md sections: one paragraph summary, Stack, Conventions, Boundaries,
Storage block. Durable, changes rarely.

CLAUDE.md content, exactly: "This file routes. Follow ./AGENTS.md."

STATUS.md sections: Now (one or two lines), Next (ordered short list),
Decisions (append only, dated, one line of why each), Blocked / waiting.
Header carries an updated date. Agents refresh it at the end of any session
that changed state.

## Automation (all code in infra repo, tools/projects/, deployed to CX33)

1. scan.sh, hourly after the backup: walks /root/projects/* and /srv/git/*.
   Per project emits: last commit time, dirty file count, unpushed commit
   count, days since STATUS.md modified, du of hot tier vs declared budget,
   systemd state when deploy is srv, newest dump age when a database is
   declared. Output: projects.json.
2. projects.html: second Personal OS page, generated from projects.json.
   Row per project, amber and red dots for staleness and budget overrun,
   Now and Next pulled from STATUS.md. Copied to the box hourly, readable
   from the phone.
3. new-project.sh <name>: scaffold. Creates the directory and three files
   from templates, git init on main, optional gh repo create, optional srv
   deploy wiring (bare repo, post receive hook, systemd unit, Caddy entry),
   installs the `p` helper on first run.
4. Backup extension: hourly job adds /srv/git and /srv to the mirror.
   Closes the Scriptura gap where app history existed on one server only.

## Error handling and edge cases

- scan.sh must not die on a broken project: per project failures are
  captured as a status field, the scan always completes.
- Projects without the three files appear on the page flagged
  "unmanaged" rather than hidden. Adoption is visible, not forced.
- Budget overruns and stale dumps are warnings on the page, nothing is
  auto deleted, consistent with the standing never delete rule.
- projects.json is written atomically (temp file then move) so the page
  never renders a half written scan.

## Testing

- Scaffold a throwaway project, verify all files, budgets, and page row.
- Break a repo on purpose (delete .git) and verify the scan survives and
  flags it.
- Declare a database with no dumps and verify the warning appears.
- Verify /srv/git appears in the backup listing on the box after the next
  hourly run.

## Out of scope for this build

- Mac file overhaul (separate project, applies these conventions later).
- Migrating the 19 Playground directories (follow on, uses new-project
  conventions per project as they move).
- Notion or any external tracker.
- Multi user permissions; single operator assumed.
