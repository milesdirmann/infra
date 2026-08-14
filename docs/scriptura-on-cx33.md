# Scriptura on CX33 (RETIRED 2026-08-14)

> **This service no longer exists.** The project was discontinued and removed
> from CX33 on 2026-08-14: `scriptura.service`, `/srv/scriptura`,
> `/root/scriptura`, `/srv/git/scriptura.git`, and the `scriptura` system user
> are all gone, and the Caddy routes that served it were dropped.
>
> Everything is archived to `sbox:archive/scriptura-retired-2026-08-14/`: the
> app tree and checkout, the bare repo (1,413 entries), the systemd unit, and
> the Caddyfile as it stood before. Scriptura had no GitHub remote, so **that
> archive is the only surviving copy.**
>
> `api.scouq.com` used to proxy here, which is why a Scouq hostname served a
> Scripture memorization app. It now returns 410 and is reserved for Scouq OS.
>
> The rest of this document is kept as the record of how it was deployed. The
> bare-repo plus systemd plus Caddy pattern it established is still the
> standard for new apps on the box.

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

## Domain (added 2026-07-25)

`api.scouq.com` → 89.167.110.196, A record, **DNS-only** (not proxied — Caddy
needs to answer the ACME HTTP-01 challenge itself). The record previously
pointed at the decommissioned CPX31 and was repointed, not created.

Caddy serves the hostname and the bare IP from the same site block and holds a
Let's Encrypt certificate for it. `ufw` now allows 443/tcp.

The iOS bundle defaults `SCRIPTURA_API_BASE` to `https://api.scouq.com`
(`vite.cap.config.ts`), because the native build is served from
`capacitor://localhost` and has no origin of its own. Without it the
translation picker and account section silently render nothing.

`YOUVERSION_API_KEY` is set via `/etc/systemd/system/scriptura.service.d/10-youversion.conf`
(mode 600). It is issued under **non-commercial terms** and is valid only while
Scriptura ships free — remove it before any paid build. Verify with
`curl 'https://api.scouq.com/api/bible?op=versions'`.

### Still open
- Course video: YouTube embeds cannot play from a `capacitor://` origin
  (Error 153) and no client config fixes it — WKWebView reserves http/https.
  The fix is a small embed page served from this host so the request to YouTube
  carries a real https referrer. Not built yet. See the app repo's
  `docs/COURSE-VIDEO.md`.

## The course-video shim (added 2026-07-27)

`/srv/scriptura/site/embed.html`, served at **https://api.scouq.com/embed?v=<id>**
via a `handle /embed` block in the Caddyfile.

Why it exists: YouTube's player refuses any framing origin that is not
http(s), and the iOS app is served from `capacitor://localhost`. Every course
video failed with "Error 153" and no client-side setting could fix it, because
WKWebView reserves http/https and will not hand them to a custom scheme
handler. The app frames this page instead; the request to YouTube then carries
a genuine https referrer. That the page is itself framed from `capacitor://`
is not something the embed checks.

Verified playing in the app on 2026-07-27.

It validates the id against `^[A-Za-z0-9_-]{11}$` before framing anything and
forwards only fixed player flags, so it cannot be turned into a frame for
arbitrary third-party content by anyone who can hand someone a link.

Dependency-free and cached for 5 minutes. It is on the critical path for every
course video, so keep it boring.
