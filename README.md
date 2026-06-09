# ghrian-server

The server module of the ghrian project: a Ruby on Rails 8 app that subscribes to
the live inverter data the [`ghrian-agent`](https://github.com/zavan/ghrian-agent)
publishes to MQTT, persists
it to a database, serves it as a token-authenticated REST API (for clients like a
future native macOS app), and provides a Hotwire admin/dashboard.

```
inverter ──Modbus──▶ [agent] ──MQTT──┬──▶ [server] ──DB / dashboard / REST API──▶ [clients]
                                      └──▶ [homekit] ──HAP──▶ Apple Home / Siri
```

Unlike the agent and homekit modules (small Go services configured by files/flags),
the server has a UI, so **configuration lives in the database** and is managed
through the admin — you add inverters and set up the MQTT connection in the browser,
not in a YAML file.

## Stack (railsy defaults)

- **Rails 8.1**, Ruby 4 — import maps, Hotwire (Turbo + Stimulus), Propshaft.
- **SQLite** for the database **and** for Solid Queue / Cache / Cable.
- **Tailwind CSS** via `tailwindcss-rails` (standalone CLI — no Node bundler).
- **Authentication** from the built-in `bin/rails generate authentication`.
- **Minitest** + fixtures.
- Installable **PWA** (manifest + service worker).

## Architecture

The whole pipeline downstream of Modbus is observational; the server only **reads**
the agent's MQTT stream and never publishes to the inverter. Following 37signals
conventions, there is **no `app/services` layer** — behavior lives on the models
(rich models + concerns), and the one non-AR collaborator (the MQTT listener) is a
plain PORO under `app/models`.

| Concern | Where |
| --- | --- |
| MQTT subscribe loop (separate process) | `app/models/mqtt/listener.rb` + `bin/mqtt-listener` |
| Decode payload → persist → broadcast | `Inverter.ingest` / `#record_reading` / `#apply_availability` |
| Live dashboard broadcasting | `app/models/concerns/broadcastable.rb` |
| Broker settings (singleton, encrypted pass) | `MqttConfig` |
| Inverters (shared, topic-keyed, cached snapshot) | `Inverter` (`latest_values` JSON) |
| One MQTT message | `Reading` (`data` JSON = the agent's `values` map) |
| Daily energy rollup (month/year/lifetime) | `DailySummary` (one row per inverter/day) |
| Electricity pricing (singleton) | `Tariff` (import/export rates → cost/earnings/net/savings) |
| API bearer tokens (per user) | `ApiToken` + `ApiTokenAuthentication` concern |

The **dashboard** and each inverter's page (`/inverters/:id`) show **Day / Month / Year /
Lifetime** energy totals with **cost figures** (import cost, export earnings, net,
self-consumption savings) driven by the tariff you set under **Costs** — site-wide on the
dashboard, per-inverter on the inverter page. Daily totals are rolled up from the agent's
cumulative `today_*` counters as readings arrive, so history builds forward from when the
server starts ingesting.

The listener subscribes to one wildcard (`<base_topic>/#`) and matches each message
to an `Inverter` by its `mqtt_topic`, so newly added inverters are picked up live
without a restart. Editing the broker settings reconnects the listener
automatically (best-effort; a `mqtt` process restart is always a safe fallback).

## Input payload (shared with the agent)

Each metric is self-describing `{ value, unit, label }`; bitfields also carry
`<name>_active: []string`. Decoding is defensive (values may be number, string, or
array). The retained `<topic>/availability` (`online`/`offline`) maps to inverter
status. See the project-wide
[payload contract](https://github.com/zavan/ghrian/blob/main/docs/payload.md) for
the authoritative shape.

## Getting started

```bash
bin/setup                      # installs gems, prepares the DB
bin/rails db:encryption:init   # if credentials lack encryption keys (see below)
bin/dev                        # starts web + mqtt-listener + tailwind watcher (foreman)
```

### Accounts (public-deploy safe)

Public sign-up is open **only until the first account exists** — the first visit to a
fresh deploy bootstraps your admin. After that, registration is closed and further
accounts are created from the **Users** admin page (every account is an admin of the
shared installation). You can't remove your own account or the last one.

Then open http://localhost:3000, create an account, and in the admin:

1. **MQTT → Edit**: set host/port and base topic (e.g. `localhost` / `1883` / `ghrian`).
2. **Inverters → Add inverter**: set the MQTT topic the agent publishes to
   (e.g. `ghrian/inverter/01`).
3. **API Tokens**: generate a token for API clients.

> **Encryption keys:** `MqttConfig#password` is encrypted with Active Record
> Encryption. If the app can't boot for lack of keys, run `bin/rails
> db:encryption:init` and add the printed block to your credentials
> (`bin/rails credentials:edit`).

## Dev against the real agent (reuse its broker)

You only need an MQTT broker on `localhost:1883` publishing under `ghrian/#` — any
broker works. The easiest is to reuse the one shipped with
[`ghrian-agent`](https://github.com/zavan/ghrian-agent): clone it alongside this
repo and start its dev mosquitto.

```bash
# in a clone of ghrian-agent:
make dev-up                                  # mosquitto on localhost:1883 (anonymous, ghrian/#)

# in this repo:
bin/dev                                      # web + listener + css
# Configure MqttConfig (localhost:1883, base_topic ghrian) and add inverter ghrian/inverter/01.

# back in ghrian-agent, point it at your inverter (or fake one reading):
make go-run ARGS="--config config.yml"       # or `make dev-pub` to publish a sample reading
```

Watch the dashboard tiles update **live** (Turbo Streams, no refresh).

## REST API

Bearer-token authenticated (`Authorization: Bearer <token>`), JSON, under `/api/v1`:

| Method & path | Returns |
| --- | --- |
| `GET /api/v1/inverters` | all inverters + status + latest snapshot |
| `GET /api/v1/inverters/:id` | one inverter + snapshot |
| `GET /api/v1/inverters/:id/readings` | time-series; params: `from`, `to`, `metric`, `limit` |

```bash
curl -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/v1/inverters
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/api/v1/inverters/1/readings?metric=battery_soc&from=2026-06-09T00:00:00Z"
```

Requests without a valid token get `401`.

## Tests

```bash
bin/rails test     # minitest; ingestion is covered hermetically (no broker needed)
bin/rubocop        # rails-omakase style
```

## Docker

Published to Docker Hub as
[`zavan/ghrian-server`](https://hub.docker.com/r/zavan/ghrian-server) (multi-arch:
amd64 + arm64). The image runs the **web** process by default (Thruster on `:80`,
auto-running `db:prepare` on boot). The **MQTT listener** is the *same image* with
the command overridden — run both on the same host so they share the SQLite volume.

The image is **self-serve**: it reads its secrets from the environment, so you don't
need a Rails `master.key`. Generate four random values once (`openssl rand -hex 64`
for `SECRET_KEY_BASE`, `-hex 32` for each `AR_ENCRYPTION_*`) and keep them stable:

```bash
# web — serves the dashboard + API and migrates the DB on boot (start this first)
docker run -d --name ghrian-web -p 80:80 \
  -e SECRET_KEY_BASE=... \
  -e AR_ENCRYPTION_PRIMARY_KEY=... \
  -e AR_ENCRYPTION_DETERMINISTIC_KEY=... \
  -e AR_ENCRYPTION_KEY_DERIVATION_SALT=... \
  -v ghrian-storage:/rails/storage \
  zavan/ghrian-server

# listener — ingests MQTT; same image + volume + env, different command
docker run -d --name ghrian-mqtt --env-file server.env \
  -v ghrian-storage:/rails/storage \
  zavan/ghrian-server bin/mqtt-listener
```

The `AR_ENCRYPTION_*` keys encrypt any broker password you save, so keep them
stable. (If you build your own image with baked-in credentials, `RAILS_MASTER_KEY`
still works as an alternative.) For the full stack in one command, see the
[`compose.yml`](https://github.com/zavan/ghrian) in the umbrella repo. Tags:
`X.Y.Z` / `latest` from releases, `edge` tracks `main`.

## Production

`Procfile` processes: `web` (Puma) and `mqtt` (`bin/mqtt-listener`). Deploy with
Kamal (`config/deploy.yml`) or any process manager that runs both. Persist the
SQLite databases under `storage/` and keep `config/master.key` safe (it decrypts
credentials, including the MQTT password and encryption keys).

## License

MIT — see [LICENSE](LICENSE).
