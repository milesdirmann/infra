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
  - ✅ Working since 2026-09-02. Verified by a full restore into a scratch
    database: 124 public tables, 23 auth tables, 18,203 ledger rows, 7 auth
    users. The only restore errors are the `cron` and `supabase_vault`
    extensions, which a plain Postgres box lacks and a real Supabase target
    has.
  - ⚠️ **The pooler host is `aws-1-us-east-2`, not `aws-0`.** An `aws-0` string
    fails with `FATAL: (ENOTFOUND) tenant/user ... not found`, which reads like
    a bad password but is a wrong address. To tell them apart, connect with a
    deliberately wrong password: the correct host answers "password
    authentication failed" because it knows the tenant. Take the string from
    the dashboard (Connect → Session pooler) rather than typing it by hand.
  - Paste the password without it passing through a chat transcript:
    ```
    pbpaste | tr -d '\n' | python3 -c 'import sys,urllib.parse;print("DATABASE_URL=postgresql://postgres.dctubowsymgmgdvfqhbc:"+urllib.parse.quote(sys.stdin.read(),safe="")+"@aws-1-us-east-2.pooler.supabase.com:5432/postgres")' | ssh server 'umask 077; { grep -v "^DATABASE_URL=" /root/.tabernacle-db.env; cat; } > /root/.tabernacle-db.env.new && mv /root/.tabernacle-db.env.new /root/.tabernacle-db.env && chmod 600 /root/.tabernacle-db.env && systemctl start tabernacle-db-backup.service'
    ```

- **Failure alerting** (added 2026-09-02). The backup failed silently every
  night from late July to 2026-09-02: it logged to journald and nobody was
  watching. Two guards now exist, mirrored in `tools/server/`:
  - `tabernacle-alert@.service` is an `OnFailure=` handler on the backup unit,
    so a failed run pushes a notification immediately. It reads
    `ALERT_NTFY_TOPIC` (ntfy.sh, no account required) or `ALERT_WEBHOOK_URL`
    from `/root/.tabernacle-db.env`, logs to syslog, and writes
    `/var/lib/tabernacle-backup-alert.last` either way. Alert text names only
    the host and the job, never data, because it travels to a third party.
  - `tabernacle-backup-check.timer` runs daily at 12:00 UTC and alerts if no
    dump newer than 30h exists locally or on the Storage Box. This is the one
    that catches the timer silently not firing at all, which an `OnFailure=`
    hook by definition cannot.
  - Subscribe to the topic in the ntfy app to receive them. Rotate by editing
    `ALERT_NTFY_TOPIC`; the topic name is the only thing keeping it private.

## Open items

- No hostname / TLS yet. Candidates discussed: repoint `tabernacle.avogrowth.com`
  (currently stranded on an unreachable Vercel account) or a church-owned domain.
- Apple Developer membership purchased 2026-07 → TestFlight distribution of the
  Capacitor iOS shell is unblocked once the app points at a real https origin.
