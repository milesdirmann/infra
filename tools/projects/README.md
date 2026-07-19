# Project system tooling

The machinery behind the server-first project system. Design spec:
`docs/superpowers/specs/2026-07-19-project-system-design.md`.

## Files

- `templates/` context file templates rendered by `new-project.sh`.
  `{{NAME}}` and `{{DATE}}` are substituted. `global-AGENTS.md` is the real
  global file, deployed to `/root/AGENTS.md`.
- `lib/parse-storage.sh` reads a field from the `storage:` block of an
  AGENTS.md. Shared by the scanner.
- `scan.sh <projects_root> <srv_git_root> <out_json>` emits machine-derived
  facts per project. Never dies on one broken project.
- `generate.py <in_json> <out_html>` renders the Personal OS overview page.
- `new-project.sh <name> [--github] [--deploy]` scaffolds a project.
- `install-on-server.sh` deploys this repo's tooling onto the CX33. Idempotent.
- `doppler-setup.md` / `doppler-run-wrapper.md` secret wiring runbooks.

## The three per-project files

- `AGENTS.md` canonical, durable: what, stack, conventions, boundaries, storage.
- `CLAUDE.md` two-line router to AGENTS.md.
- `STATUS.md` volatile: now, next, decisions (append only), blocked.

## Flow

Scaffold a project, then hourly the backup timer runs `scan.sh` then
`generate.py`, writing `dashboard/projects.json` and `dashboard/projects.html`,
mirrored to the Storage Box. The page shows facts that cannot lie.
