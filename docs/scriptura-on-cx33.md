# Scriptura on CX33

First application service on CX33. Set up 2026-07-19.

**Live:** http://89.167.110.196/ (plain HTTP — no domain points here yet)

Scriptura is the Scripture-memorization phone app (Next.js on Vite via `vinext`,
React 19). Source lives in the `scriptura-mvp` branch.

## Layout

| Piece | Path / unit | Notes |
| --- | --- | --- |
| Canonical repo | `/srv/git/scriptura.git` | Bare. The Mac pushes here (`cx33` remote) |
| Checkout + build | `/srv/scriptura` | `root:scriptura`, group-read only |
| App service | `scriptura.service` | `vinext start` on `127.0.0.1:3000` as user `scriptura` |
| Public entry | `caddy` `:80` | Reverse proxy, gzip/zstd, immutable cache for `/assets` and `/bible` |
| Firewall | ufw | 22 + 80 only; 3000 is not externally reachable |

The app stores nothing server-side (all user state is browser localStorage), so
`scriptura.service` runs with `ProtectSystem=strict`, `ProtectHome`,
`NoNewPrivileges`, and a 1.5 GB memory cap. Idle footprint is ~60 MB.

## Deploy

From the Mac, on `scriptura-mvp`:

```sh
git push cx33 scriptura-mvp
```

The bare repo's `post-receive` hook checks out, runs `npm ci`, builds, restarts
the service, and health-checks it — streaming progress back to the terminal.
A failed build aborts the deploy and leaves the previous build serving.

## Operate

```sh
systemctl status scriptura        # app state
journalctl -u scriptura -f        # app logs
journalctl -u caddy -f            # access logs
```

## Adding a domain

Point an A record at `89.167.110.196`, replace `:80` in `/etc/caddy/Caddyfile`
with the hostname, `systemctl reload caddy`, then `ufw allow 443/tcp`. Caddy
gets the Let's Encrypt certificate on its own.

## Open items

- **Backups do not cover this yet.** `/srv/git/scriptura.git` is currently the
  only copy of the app's history besides the Mac working tree — Scriptura is
  *not* on GitHub, so the dashboard's "active work is on GitHub" assumption does
  not hold for it. Add `/srv/git` and `/srv/scriptura` to the hourly
  Storage Box job when `tools/server/hetzner-backup.*` is installed, and/or
  push the repo to a private GitHub repo.
- `GROQ_API_KEY` is not set, so voice recitation returns 501 and the client
  hides the mic. Add via `systemctl edit scriptura` when wanted.
- No TLS until a domain exists (see above).
