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

`nginx-xcred.location.conf` is the block added to `E:\sac\Progs\XContactMgr\nginx\nginx.conf`
(above `location / {`). Apply changes with:

```powershell
docker exec xcontactmgr-nginx-1 nginx -t
docker exec xcontactmgr-nginx-1 nginx -s reload
```

`proxy_pass http://xcred:8080/;` has a trailing slash on purpose — nginx strips `/xcred/`, so the
container sees `/api/…` and `/assets/…` exactly as it does at a site root. The web bundle itself is
built with base path `/xcred/` (compose build arg `VITE_BASE_PATH`), so the browser requests
`/xcred/assets/…`.

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

* Rolling back the nginx change: restore the `nginx.conf.bak-before-xcred-*` file next to it and reload.
* The same image also runs at a site root: build without the `VITE_BASE_PATH` arg (default `/`).
