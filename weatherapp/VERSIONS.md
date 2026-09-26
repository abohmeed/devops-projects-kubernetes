# WeatherApp 2026 — version pins

Every version was checked on 2026-09-26 against the source named in the row.
Image tags were confirmed to exist on Docker Hub (`hub.docker.com/v2/repositories/library/<image>/tags/<tag>` → 200)
and were then pulled and run on the recording VM (`dop-rec`, Ubuntu 24.04 x86_64).

## Runtimes and base images

| What | Pin | Why this one | Source (checked 2026-09-26) |
|---|---|---|---|
| Go | **1.27.1** (image `golang:1.27.1-alpine3.24`, build stage only) | Current stable; 1.27.1 released 2026-09-01 | https://go.dev/dl/?mode=json (`"version": "go1.27.1", "stable": true`); https://go.dev/doc/devel/release |
| Node.js | **24.21.0 LTS "Krypton"** (image `node:24.21.0-alpine3.24`) | 24 is the Active LTS line today (released 2026-09-07). Node 26 is Current and only becomes LTS on 2026-10-28 | https://nodejs.org/dist/index.json (`v24.21.0`, `"lts":"Krypton"`); https://nodejs.org/en/about/previous-releases |
| Python | **3.13.15** (image `python:3.13.15-slim-trixie`) | Required 3.13 line; 3.13.15 released 2026-08-05 | https://www.python.org/downloads/source/ ; https://www.python.org/ftp/python/3.13.15/ |
| Final image for auth | `alpine:3.24.2` | Same Alpine as the Go build image | Docker Hub `library/alpine` tags |
| MySQL | **8.4.11** (image `mysql:8.4.11`, official) | 8.4 is MySQL's LTS line. 8.4.12 is announced (release notes dated 2026-08-18) but **not yet on Docker Hub** (tag 404), so 8.4.11 is the newest pullable 8.4 patch | https://dev.mysql.com/doc/relnotes/mysql/8.4/en/ ; Docker Hub `library/mysql` tags |
| Chart test pods | `busybox:1.38.0` | Replaces the unpinned `busybox` in the `helm create` test template | Docker Hub `library/busybox` tags |

## Go modules (auth) — `auth/src/main/go.mod`, `go.sum`

| Module | Pin | Replaces (2021) | Source |
|---|---|---|---|
| `github.com/golang-jwt/jwt/v5` | v5.3.1 | `github.com/dgrijalva/jwt-go` v3.2.0 (archived) | https://proxy.golang.org/github.com/golang-jwt/jwt/v5/@latest |
| `github.com/gin-gonic/gin` | v1.12.0 | v1.7.7 | https://proxy.golang.org/github.com/gin-gonic/gin/@latest |
| `github.com/gin-contrib/cors` | v1.7.9 | v1.3.1 | https://proxy.golang.org/github.com/gin-contrib/cors/@latest |
| `github.com/go-sql-driver/mysql` | v1.10.1 | v1.6.0 | https://proxy.golang.org/github.com/go-sql-driver/mysql/@latest |
| `golang.org/x/crypto` (bcrypt) | v0.57.0 | — (new: replaces MD5 password hashing) | resolved by `go get golang.org/x/crypto@latest` |

Indirect modules are fixed by `go.sum` (generated with `go mod tidy` under Go 1.27.1; `go vet ./...` clean).

## npm packages (UI) — `UI/package.json` (exact pins) and `UI/package-lock.json`

| Package | Pin | 2021 | Source |
|---|---|---|---|
| express | 5.2.1 | ^4.17.1 | https://registry.npmjs.org/express/latest |
| axios | 1.20.0 | ^0.24.0 | https://registry.npmjs.org/-/package/axios/dist-tags (`latest`) |
| jsonwebtoken | 9.0.3 | ^8.5.1 | https://registry.npmjs.org/jsonwebtoken/latest |
| cookie-parser | 1.4.7 | ^1.4.6 | https://registry.npmjs.org/cookie-parser/latest |

Dropped: `body-parser` (built into Express 5 as `express.urlencoded`), `ejs` (never rendered anything), `path` (an npm polyfill of Node's built-in module).
`npm audit --omit=dev` on 2026-09-26: 0 vulnerabilities (97 packages).

## Python packages (weather) — `weather/requirements.txt`

Every package is pinned, direct and transitive; `pip freeze` in a clean `python:3.13.15-slim-trixie`
container returns exactly these 15 lines, and `pip check` reports no broken requirements.

| Package | Pin | Package | Pin |
|---|---|---|---|
| Flask | 3.1.3 | Jinja2 | 3.1.6 |
| Werkzeug | 3.1.8 | MarkupSafe | 3.0.3 |
| flask-cors | 6.0.5 | itsdangerous | 2.2.0 |
| requests | 2.34.2 | click | 8.5.0 |
| gunicorn | 26.2.0 | blinker | 1.9.0 |
| urllib3 | 2.8.0 | certifi | 2026.7.22 |
| idna | 3.20 | charset-normalizer | 3.5.1 |
| packaging | 26.3 | | |

Source for each: `https://pypi.org/pypi/<name>/json` (`info.version`), 2026-09-26.

## Tooling used to verify (on `dop-rec`)

| Tool | Pin | How installed | Source |
|---|---|---|---|
| Docker Engine | `docker-ce=5:29.8.1-1~ubuntu.24.04~noble` (+ `docker-ce-cli` same) | Docker's official apt repo, held with `apt-mark hold` | https://download.docker.com/linux/ubuntu (noble/stable); https://docs.docker.com/engine/install/ubuntu/ |
| containerd | `containerd.io=2.3.6-1~ubuntu.24.04~noble` | same repo; same pin as the programme's `VERSIONS.md` §4 | as above |
| Compose plugin | `docker-compose-plugin=5.5.1-1~ubuntu.24.04~noble` (`Docker Compose version v5.5.1`) | same repo | as above |
| Buildx plugin | `docker-buildx-plugin=0.37.1-1~ubuntu.24.04~noble` | same repo | as above |
| Helm | **v4.3.0** (programme `VERSIONS.md` §5) | `~/weatherapp-build/bin/helm`, tarball checked against `helm-v4.3.0-linux-amd64.tar.gz.sha256sum` | https://github.com/helm/helm/releases/tag/v4.3.0 (published 2026-09-09) |
| kind | v0.33.0 (throwaway cluster for an install test only; deleted afterwards) | `~/weatherapp-build/bin/kind`, sha256 checked | https://github.com/kubernetes-sigs/kind/releases/tag/v0.33.0 |
| kubectl | v1.36.4 (the course's Kubernetes patch) | `~/weatherapp-build/bin/kubectl`, sha256 checked | https://dl.k8s.io/release/v1.36.4/bin/linux/amd64/kubectl |

Note on the Compose name: the plugin's own version line is now **v5.x**. It is the same `docker compose`
(Go, plugin) generation that replaced the Python `docker-compose` v1; "Compose v2" in older docs means this plugin.
