# Global agent instructions

Durable preferences for all work on this server. Project AGENTS.md files
layer on top of this.

## Voice and copy

- Never use em dashes or en dashes. Commas, colons, periods only.
- Plain, direct, results focused. No filler.

## Secrets

- Machine secrets live in Doppler, never in committed files.
- Access secrets only through `doppler run`. Never print a secret value,
  never copy one into a file, transcript, or commit.

## Storage

- Four tiers: code on GitHub, hot on the server under /root/projects and
  /srv, cold on the Storage Box, ephemeral (regenerable) kept nowhere.
- Regenerable output (node_modules, caches, build dirs) is never backed up.
- Large or dormant data goes to the Storage Box, streamed on demand.

## Working style

- Start sessions inside the project directory so context loads.
- Update STATUS.md at the end of any session that changed state.
- Scripts are idempotent and safe to re-run.
