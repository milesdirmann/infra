# Memphis Tabernacle app on CX33

Second application on CX33, beside Scriptura. Set up 2026-07-30.

**Live:** http://89.167.110.196:8081/ (temporary port — no hostname chosen yet)

The Memphis Tabernacle member/leader app (static web: `index.html` + `app.js` +
`styles.css` + `assets/`, Capacitor shells for iOS/Android in the same repo).
All live data comes from Supabase project `tabernacle-building`
(`dctubowsymgmgdvfqhbc`, us-east-2) directly from the client; the server only
serves files. Source lives on the Mac at `~/Tabernacle/app` (own git repo,
nested untracked inside the Tabernacle folder).

## Layout

| Piece | Path / unit | Notes |
| --- | --- | --- |
| Canonical repo | `/srv/git/tabernacle.git` | Bare. The Mac pushes here (`cx33` remote) |
| Checkout | `/srv/tabernacle/checkout` | Full repo checkout |
| Web root | `/srv/tabernacle/www` | Hook copies only the four servable pieces; prior build kept at `www.old` |
| Public entry | `caddy` `:8081` | Static file_server, gzip/zstd, 1-day cache on `/assets` |
| Firewall | ufw | 8081/tcp opened alongside 22/80/443 |

No systemd unit — nothing runs server-side. The post-receive hook deploys
atomically (`www.new` → `www`, previous kept as `www.old`).

## Deploy

From the Mac, in `~/Tabernacle/app`:

```sh
git push cx33 main
```

## Adding a domain

Point an A record at `89.167.110.196` (DNS-only if Cloudflare — Caddy answers
its own ACME challenge), replace `:8081` with the hostname in
`/etc/caddy/Caddyfile`, `systemctl reload caddy`. 443 is already open. Then
`ufw delete allow 8081/tcp`.

A backup of the pre-Tabernacle Caddyfile is at
`/etc/caddy/Caddyfile.bak-tabernacle`.

## Backups (added 2026-07-30)

- **App + repos**: the existing hourly `hetzner-backup.timer` mirrors all of
  `/srv` to `sbox:backups/srv` — `tabernacle.git` and the deployed checkout are
  covered (verified on the box 2026-07-30). This also closed Scriptura's old
  "no backup" open item.
- **Supabase database**: `tabernacle-db-backup.timer` (nightly 08:30 UTC ±15m,
  ~03:30 Memphis) runs `/usr/local/bin/tabernacle-db-backup.sh`: `pg_dump`
  custom-format → `/root/backups/tabernacle-db/` → `sbox:backups/tabernacle-db`.
  Retention 7d local / 60d box. Sources `/root/.tabernacle-db.env` (mode 600).
  The direct DB host is IPv6-only and unreachable from CX33 — the env file must
  hold the **session pooler** string (IPv4). Files mirrored in
  `tools/server/tabernacle-db-backup.*`.
  - ⚠️ `DATABASE_URL` is still empty — the first run will fail until the pooler
    string from the Supabase dashboard (Connect → Session pooler) is pasted in.

## Open items

- No hostname / TLS yet. Candidates discussed: repoint `tabernacle.avogrowth.com`
  (currently stranded on an unreachable Vercel account) or a church-owned domain.
- Apple Developer membership purchased 2026-07 → TestFlight distribution of the
  Capacitor iOS shell is unblocked once the app points at a real https origin.
