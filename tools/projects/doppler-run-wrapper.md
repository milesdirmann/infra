# Running a service with Doppler secrets

Systemd ExecStart wraps the process so secrets live in memory only:

    Environment=DOPPLER_TOKEN_FILE=/etc/doppler/<name>.token
    ExecStart=/bin/sh -c 'DOPPLER_TOKEN=$(cat $DOPPLER_TOKEN_FILE) doppler run --fallback --command "node server.js"'

--fallback keeps an encrypted local cache so a Doppler outage or offline
restart still works. The cache is gitignored and excluded from backup.
