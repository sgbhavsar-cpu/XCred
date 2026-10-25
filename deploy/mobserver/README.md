# XCred behind the XContactMgr nginx (`mobserver.ssm-infotech.com:1976/xcred/`)

XCred runs as its own container (`xcred`) on the same Docker network as XContactMgr
(`xcontactmgr_xcm_internal`). The existing nginx container terminates TLS on port 1976 and forwards
`/xcred/` to it, so no new port is opened and everything is HTTPS.

```
phone / browser ──https:1976──▶ xcontactmgr-nginx-1 ──/xcred/──▶ xcred:8080   (SQLite in volume)
                                         └────────── /  ──────▶ api:3000      (XContactMgr, unchanged)
```

## URLs

| What | URL |
|---|---|
| Web app | `https://mobserver.ssm-infotech.com:1976/xcred/` |
| API (used by the apps) | `https://mobserver.ssm-infotech.com:1976/xcred/api/…` |
| Mobile app → Server Setup | `https://mobserver.ssm-infotech.com:1976/xcred` |

The first account registered becomes the admin.

## Deploy / update

```powershell
cd E:\sac\Progs\XCred
docker compose -f deploy/mobserver/docker-compose.yml up -d --build
```

Data (SQLite database + generated JWT secret) lives in the `xcred_xcred_data` volume and survives
rebuilds. Logs are in `xcred_xcred_logs`.

## nginx

Two files in this folder are applied to `E:\sac\Progs\XContactMgr\nginx\nginx.conf`:

* `nginx-xcred.http.conf` — goes at the top of the file, above `server {` (the auth rate-limit map + zone).
* `nginx-xcred.location.conf` — goes inside `server { }`, above `location / {` (the `/xcred/` proxy block).

Apply changes with:

```powershell
docker exec xcontactmgr-nginx-1 nginx -t
docker exec xcontactmgr-nginx-1 nginx -s reload
```

`proxy_pass http://xcred:8080/;` has a trailing slash on purpose — nginx strips `/xcred/`, so the
container sees `/api/…` and `/assets/…` exactly as it does at a site root. The web bundle itself is
built with base path `/xcred/` (compose build arg `VITE_BASE_PATH`), so the browser requests
`/xcred/assets/…`.

### What the `/xcred/` block adds on top of plain proxying

| Protection | Detail |
|---|---|
| Security headers | `X-Content-Type-Options`, `X-Frame-Options: DENY`, `Referrer-Policy`, `Permissions-Policy`, COOP/CORP, and a strict `Content-Security-Policy` (same-origin only; no `unsafe-eval`; `unsafe-inline` for styles only). Sent on every response. |
| Login throttle | `/xcred/api/auth/{login,register,refresh}` limited to 30 req/min + burst 20 (HTTP 429). Every other path is unlimited. |
| Version hiding | `server_tokens off` (server-wide). |
| Header spoofing | `X-Forwarded-For` is *replaced* with the address nginx saw, never appended to a client-supplied value. |

Not enabled on purpose: **HSTS** (applies to the whole host name on every port and can't be undone for
`max-age`; the line is in the location file, commented, for when you're ready).

### Known limitation: client addresses

Docker Desktop for Windows rewrites every client's address to the Docker gateway (`172.19.0.1`) before
nginx sees it, so XCred's audit log, failed-login alert emails and the rate limit all see one shared
address. The XCred side is ready (`ForwardedHeaders__TrustedNetworks` in the compose file makes it trust
nginx's header) and will record real addresses automatically if nginx ever sees them (native nginx on the
host, or host networking). Until then the limit is effectively global — sized generously for that.

## Backup / restore

```powershell
# backup
docker run --rm -v xcred_xcred_data:/data -v ${PWD}:/backup alpine tar czf /backup/xcred-data.tgz -C /data .
# restore (stop the container first)
docker run --rm -v xcred_xcred_data:/data -v ${PWD}:/backup alpine sh -c "cd /data && tar xzf /backup/xcred-data.tgz"
```

Keep `jwt-secret.txt` with the database backup — without it every logged-in session is invalidated
(users just log in again; vault data is unaffected).

## Notes

* Rolling back nginx: restore `nginx.conf.bak-before-hardening-*` (hardening only) or `nginx.conf.bak-before-xcred-*` (everything XCred) next to the config, then `nginx -t` and reload.
* The same image also runs at a site root: build without the `VITE_BASE_PATH` arg (default `/`).
