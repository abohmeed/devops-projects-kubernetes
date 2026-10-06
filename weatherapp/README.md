# WeatherApp (2026 rebuild, v3.0.0)

The sample application used across the course: Section 3 builds and runs it in containers, with
Docker Compose and with Helm; Section 4's GitLab pipeline builds and deploys it; Section 5 backs up
its MySQL volume. The 2021 app is rebuilt here on current, supported runtimes. **Its shape is
unchanged:** the same three services, ports, endpoints, user flow, chart names, release names, and
Kubernetes object names.

## Layout

```
weatherapp/
├── auth/                   Go service, port 8080: signup, login (issues a JWT); talks to MySQL
│   ├── Dockerfile          multi-stage: golang:1.27.1-alpine3.24 → alpine:3.24.2, runs as uid 10001
│   └── src/main, src/authdb
├── UI/                     Node service, port 3000: web pages, forwards to auth and weather
│   └── Dockerfile          node:24.21.0-alpine3.24, runs as uid 1000 (node)
├── weather/                Python/Flask service, port 5000: city table + MET Norway forecast (no API key)
│   └── Dockerfile          python:3.13.15-slim-trixie + gunicorn, runs as uid 10001
├── compose.yaml            Docker Compose: the three services plus MySQL (mysql:8.4.11)
├── .env.example            placeholder secrets. Copy it to .env (never commit .env)
├── weatherapp-auth/        Helm chart for auth
│   └── charts/mysql/       our own MySQL chart on the official mysql image (replaces Bitnami)
├── weatherapp-weather/     Helm chart for weather
├── weatherapp-ui/          Helm chart for the UI (Service type LoadBalancer)
└── VERSIONS.md             every pin, with its source and the date it was checked
```

### Endpoints (unchanged from 2021)

| Service | Method and path | What it does |
|---|---|---|
| auth | `GET /` | health: 200 when MySQL answers, 500 when it does not |
| auth | `POST /users` `{"user_name","user_password"}` | sign up: 200, or 422 "User already exists" |
| auth | `POST /users/<name>` `{"user_name","user_password"}` | log in: 200 `{"JWT": "..."}`, or 403 "Bad credentials" |
| weather | `GET /` | health |
| weather | `GET /<city>` | current weather JSON (MET Norway data, city from the bundled table) |
| UI | `GET /login`, `/signup`, `/`, `/logout`, `/health`; `POST /login`, `/signup`; `GET /weather/<city>` | the pages and form handlers |

## Run it locally (Docker Compose)

Needs Docker Engine with the Compose plugin (`docker compose`, not the old `docker-compose`).

```bash
cp .env.example .env        # then put real values in .env
docker compose up --build   # add -d --wait to run in the background until all are healthy
```

Open http://localhost:3000, sign up, log in, and look up a city. Without a `WEATHER_CONTACT` the app
still runs: the lookup answers with an error message saying the contact is missing.

```bash
docker compose down -v      # stop and delete the MySQL volume too
```

`.env` holds: `DB_ROOT_PASSWORD` (MySQL root, used by MySQL and admins only), `DB_USER` and
`DB_PASSWORD` (the app's own MySQL user), `JWT_SECRET` (shared by auth and UI), `WEATHER_CONTACT`
(not a secret: an email address or URL where MET Norway can reach you).
Compose refuses to start if any of the first four is missing.

## Deploy it with Helm 4

Build and push the three images to your registry first, then:

```bash
helm upgrade --install weatherapp-auth ./weatherapp-auth \
  --set image.repository=<registry>/weatherapp-auth --set image.tag=<tag> \
  --set jwtSecret="$JWT_SECRET" \
  --set mysql.auth.rootPassword="$DB_ROOT_PASSWORD" --set mysql.auth.password="$DB_PASSWORD"
helm upgrade --install weatherapp-weather ./weatherapp-weather \
  --set image.repository=<registry>/weatherapp-weather --set image.tag=<tag> \
  --set contact="$WEATHER_CONTACT"
helm upgrade --install weatherapp-ui ./weatherapp-ui \
  --set image.repository=<registry>/weatherapp-ui --set image.tag=<tag> \
  --set jwtSecret="$JWT_SECRET"
```

The release names matter: the UI finds the other two at the Services `weatherapp-auth` and
`weatherapp-weather`, and auth finds MySQL at `<release>-mysql`. The auth chart refuses to render
without `jwtSecret`, `mysql.auth.rootPassword` and `mysql.auth.password`.

What the auth release creates for MySQL (the same names the 2021 Bitnami chart produced):

| Object | Name |
|---|---|
| StatefulSet | `weatherapp-auth-mysql` (pod `weatherapp-auth-mysql-0`) |
| Services | `weatherapp-auth-mysql`, `weatherapp-auth-mysql-headless` |
| PersistentVolumeClaim | `data-weatherapp-auth-mysql-0` (8Gi, default StorageClass) |
| Secret | `weatherapp-auth-mysql`, keys `mysql-root-password`, `mysql-password` |

`kubectl exec -it weatherapp-auth-mysql-0 -- mysql -uroot -p` works as before; the table is `auth.users`.

## What changed from 2021, and why

**Runtimes** (full list with sources in `VERSIONS.md`)
- Go 1.17 → 1.27.1; `dgrijalva/jwt-go` (archived) → `golang-jwt/jwt/v5`; gin, cors and the MySQL driver to current releases.
- Node 17 (never an LTS, end of life June 2022) → Node 24 LTS; Express 5, axios 1.x, jsonwebtoken 9.
- Python 3.8 (end of life) → 3.13; Flask 2.0 → 3.1. **Every** Python package is pinned, including the
  transitive ones: the 2021 weather image crashed at start because Werkzeug was unpinned and a later
  Werkzeug removed a function the old Flask imported.
- MySQL `mysql` (untagged, which now pulls 9.x) → `mysql:8.4.11`, the LTS line, pinned.

**Build**
- The 2021 auth Dockerfile ran `git clone` of GitHub, so local edits were ignored. All three Dockerfiles now `COPY` the local source.
- Every base image is pinned by tag; every container runs as a non-root user.
- The weather service runs under gunicorn instead of Flask's development server.

**Secrets**
- Nothing secret is in the source any more. The 2021 files carried a RapidAPI key, the JWT signing secret
  (in both auth and UI) and DB passwords; those must be treated as leaked. They now come from `.env`
  (Compose) or `--set`/Secrets (Helm). `.env.example` holds placeholders only.
- The app logs in to MySQL as its own user (`weatherapp`, rights on the `auth` database only), not as root.
  MySQL creates the database and user on first start (`MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`).

**Weather data (v3.0.0, 2026-10-06): no API key, no trial, no sign-up**
- v2.1.0 called WeatherAPI.com with a personal key. That key came from a free trial that expires, so a
  student following the course a year later would hit a dead end, exactly what broke the 2021 app
  (it used RapidAPI). v3.0.0 needs no key from anyone.
- The city is looked up in `weather/cities.csv`, built into the image: every city with at least 100,000
  people from [GeoNames](https://www.geonames.org/) (6,279 rows, CC BY 4.0). A name that several cities
  share gives the most populous one (London, United Kingdom).
- The weather comes from MET Norway's free [Locationforecast 2.0](https://api.met.no/weatherapi/locationforecast/2.0/documentation)
  API (data CC BY 4.0, commercial use allowed). Its [terms](https://api.met.no/doc/TermsOfService) ask every
  app to identify itself in the User-Agent with a way to contact it, so the service sends
  `weatherapp/3.0.0 <WEATHER_CONTACT>`, and it keeps each forecast until the `Expires` time MET Norway sends
  (no repeat calls inside that window).
- The JSON keeps the fields the UI reads (`location.name`, `location.country`, `current.temp_c`,
  `current.temp_f`, `current.feelslike_c`, `current.feelslike_f`, `current.condition.text`, `.icon`), plus
  `source`, the attribution the UI shows under the result. "Feels like" is the apparent temperature
  (Steadman), from temperature, humidity and wind.
- Weather icons are MET Norway's open icon set (MIT, `UI/public/static/weather-icons/`), served by the UI.
- `WEATHER_CONTACT` replaces `WEATHER_API_KEY`. It is configuration, not a secret, so the weather chart has
  no Secret any more: `--set contact=...` becomes a plain environment variable.

**Behaviour** (same flow; defects fixed)
- A missing contact, a refused request, an unknown city or an unreachable provider return a clear JSON error
  (503, 502, 404, 504) instead of passing the provider's raw text through; the UI shows the message.
  In 2021 the UI never answered the browser when the weather call failed.
- Passwords are stored as bcrypt hashes (were unsalted MD5), and SQL queries are parameterised (were built
  with string formatting, open to SQL injection).
- auth keeps one database connection pool (2021 opened a new one per request) and waits for MySQL
  instead of crashing until it happens to be up.
- The UI's `/weather/<city>` now requires a logged-in user, like the page that calls it.

**Compose** (`docker-compose.yaml` → `compose.yaml`)
- Healthchecks on all four services, and `depends_on: condition: service_healthy`, replace the 2021
  "restart until MySQL is up" behaviour. The MySQL check connects over TCP as the app user, so it only
  passes once MySQL has finished its first-run setup.
- The obsolete `version:` key is gone; MySQL data is in a named volume (`db-data`).

**Helm**
- Charts regenerated with Helm 4.3.0's `helm create` and the 2021 changes re-applied: `values.yaml`
  image and service settings, `env` in `deployment.yaml`, UI Service `type: LoadBalancer` on port 80.
  (v2.1.0 also had a weather `secret.yaml` for the API key; v3.0.0 has no key, so it is gone.)
- The Bitnami `mysql` dependency is gone (its chart version and images no longer exist). MySQL is a small
  chart of our own in `weatherapp-auth/charts/mysql`, on the official image, keeping Bitnami's object and
  secret-key names (table above) and the `mysql.auth.rootPassword` value.
- New values: `jwtSecret` (auth and ui; same value in both), `mysql.auth.password` (the app user's password).
- auth has a startup probe: on a first install MySQL takes a while to initialise, and without it the
  liveness probe restarted auth while it was waiting.
- MySQL stores its data in `data/` inside the volume (`--datadir=/var/lib/mysql/data`), because a new
  EBS volume has a `lost+found` directory at its root and MySQL will not initialise a non-empty directory.
- Helm 4 notes: `--atomic` is now `--rollback-on-failure`, and installs use server-side apply by default.
  No `helm dependency build` is needed: the MySQL chart ships inside `charts/`.

## Attribution

- Weather data: MET Norway, Locationforecast 2.0, licensed under CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/). Values are converted (Fahrenheit, apparent temperature, km/h).
- Places: GeoNames (https://www.geonames.org/), CC BY 4.0; filtered to cities of 100,000 people or more.
- Weather icons: github.com/metno/weathericons, MIT License, copyright (c) 2015-2017 Yr (see `UI/public/static/weather-icons/LICENSE`).
