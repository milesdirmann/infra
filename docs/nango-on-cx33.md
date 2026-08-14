# Nango on CX33

Scouq's OAuth broker for customer integrations. Set up 2026-08-14, in the slot
Scriptura vacated the same day.

**Live:** https://nango.89-167-110-196.sslip.io/ (see the hostname warning below)

Customers connect their own Twilio, Stripe, Meta and Google accounts through
Nango; Scouq stores no provider passwords of its own and never asks a customer
to paste a token. Nango handles the OAuth dance, token refresh, and
per-connection credential storage for 400+ providers, which is the most
tedious and most repeatedly-gotten-wrong part of integration work.

## Licence

Elastic License 2.0. It permits running Nango as internal infrastructure,
which is exactly this. What it forbids is offering **Nango itself** to third
parties as a hosted service. Scouq's customers connect their own accounts and
never touch Nango, so the line is not close. Do not resell it.

## What it is, and what it is not

Nango is the **broker, not the source of truth**. Provider data still arrives
through Scouq's own normalizers and lands in the `events` table. Nothing in
the product queries these containers to render a screen. If that boundary ever
blurs, Scouq's "every number derives from stored events" law quietly stops
being true, because half the numbers would then live in a vendor's schema.

Nango also does not cover every credential. It brokers OAuth for providers it
supports; anything else (a Twilio auth token typed in by hand, a Stripe
restricted key) goes through Scouq's own envelope encryption in the `secrets`
schema. **Two credential paths is the honest description.** Do not assume
Nango covers everything.

## Layout

| Piece | Path / unit | Notes |
|---|---|---|
| Compose project | `/srv/nango/docker-compose.yaml` | `nango-server` + `nango-db` |
| Secrets | `/srv/nango/.env` | `chmod 600`, root only. Backed up to `sbox:archive/nango-secrets-2026-08-14/` |
| Data volume | `/srv/nango/nango-data` | Postgres 16 data directory |
| Public route | `/etc/caddy/conf.d/nango.caddy` | Caddy owns HTTPS |
| Server port | `127.0.0.1:3003` | Loopback only |
| Connect UI port | `127.0.0.1:3009` | Loopback only |
| Database | not published | Deliberately no host port |

## Logging in: `FLAG_AUTH_ENABLED` reads backwards

Set it to **`false`**. The name suggests it turns authentication off; what it
actually does is documented in Nango's own `.env.example`:

> Uncommenting those env vars will disable regular login, signup and enable
> basic auth protection.

So `false` means "no public account system, use HTTP basic auth with
`NANGO_DASHBOARD_USERNAME` / `NANGO_DASHBOARD_PASSWORD`", which is what a
single-operator self-hosted instance wants. Setting it to `true` enables
Nango's own email and password account system **including an open `/signup`
page**, which on a public hostname means anyone on the internet can register
on your instance. That happened here on 2026-08-14 and was open for roughly
fifteen minutes before being closed; no accounts were created.

Verify after any change to this flag:

```sh
curl -sI https://<host>/api/v1/basic | grep -i 'HTTP/\|www-authenticate'
# want: 401 + www-authenticate: Basic realm="Users"
curl -s -o /dev/null -w '%{http_code}\n' -X POST https://<host>/api/v1/account/signup
# want: 404, meaning the signup route does not exist
```

Checking that `/signup` returns 404 is not enough on its own, because the
frontend is a single-page app: every path returns the HTML shell with a 200
whether or not anything backs it. Test the API, not the page.

## Two things that will bite if forgotten

**`NANGO_ENCRYPTION_KEY` is the whole thing.** It encrypts every customer's
OAuth tokens at rest. Lose it and every connection has to be reauthorized by
hand, by customers, one at a time. It is in `/srv/nango/.env` and backed up to
the Storage Box; that backup is not optional.

**The hostname is baked into every OAuth app you register.** Providers store
`NANGO_PUBLIC_SERVER_URL` as the redirect URI, so changing the hostname later
means re-registering each connected app with each provider. The current
`sslip.io` name is a placeholder. **Choose a real subdomain (something like
`connect.scouq.com`, DNS in Cloudflare) BEFORE registering the first provider
app**, then update `.env`, `nango.caddy`, and restart. After that point the
cost of changing it goes up sharply.

## Operating it

```sh
cd /srv/nango
docker compose ps
docker compose logs -f nango-server
docker compose pull && docker compose up -d   # upgrade
docker compose down                            # stop (data survives in ./nango-data)
```

Both containers use `restart: unless-stopped` and `docker.service` is enabled
at boot, so the stack comes back on its own after a reboot.

## Footprint

About 460MB of RAM and a few GB of disk at rest, on a box with 5.6GB available
and 44GB free. It is not the constraint.

## Why it sits here and not on Vercel

Nango is a long-running server with a database. Vercel's functions cannot host
either. The CX33 already runs Caddy with automatic Let's Encrypt and the
bare-repo plus systemd pattern, so this is the natural home. Scouq's web app
stays on Vercel and talks to Nango over HTTPS.
