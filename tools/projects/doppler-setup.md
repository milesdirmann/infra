# Doppler setup (operator, one time per project)

Prereq (Miles, once on the CX33): `doppler login`

Per project:
1. `doppler projects create <name>`
2. Add secrets in the dashboard (paste current keys, rotate on the way in).
3. Create a scoped service token, read-only, config `prd`:
   `doppler configs tokens create ci --project <name> --config prd --plain > /etc/doppler/<name>.token`
   `chmod 600 /etc/doppler/<name>.token`
4. In the project set `storage.secrets: doppler` in AGENTS.md.

A token in /etc/doppler/<name>.token can read that project's secrets and
nothing else. Never print a token or a secret value.
