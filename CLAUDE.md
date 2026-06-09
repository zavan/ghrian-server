# AGENTS.md — ghrian-server

**Project**: The server module of ghrian — a Rails 8 app that ingests the agent's
MQTT inverter stream, persists it, serves a token-authenticated REST API, and
provides a Hotwire admin/dashboard (installable PWA).

**Where it sits**: Peer of the homekit bridge; both are consumers of the same MQTT
stream the [agent](https://github.com/zavan/ghrian-agent) produces.

```
inverter ──Modbus──▶ [agent] ──MQTT──┬──▶ [server]  (DB / dashboard / REST API)
                                      └──▶ [homekit] ──HAP──▶ Apple Home / Siri
```

## Important invariants (don't break these)

- **No `app/services`.** 37signals/DHH style: behavior lives on the models (rich
  models + concerns); the only non-AR collaborator is a PORO under `app/models`
  (`Mqtt::Listener`). Do not add a service-object layer.
- **Ingestion is model behavior.** `Inverter.ingest(topic:, payload:)` routes a
  message → `#record_reading` (data) / `#apply_availability` (online/offline). The
  MQTT library code stays thin and out of the parsing path so ingestion is testable
  with **no broker** (see `test/models/inverter_test.rb`).
- **Read-only / observational.** The server never publishes to MQTT or the inverter.
  Mirror the agent's read-only ethos.
- **Config lives in the DB, not files.** Inverters and the broker connection are
  managed through the admin (`Inverter`, `MqttConfig` singleton). There is no
  inverter/broker YAML. `MqttConfig#password` is encrypted (`encrypts`).
- **Consume the agent payload verbatim.** Each metric is `{ value, unit, label }`;
  bitfields add `<name>_active: []string`. Decode defensively (number/string/array,
  missing keys tolerated). Honor the retained `<topic>/availability`.
- **One wildcard subscription.** The listener subscribes to `<base_topic>/#` and
  matches messages to inverters by `mqtt_topic`, so new inverters need no restart.
- **JSON columns need the attribute type.** SQLite returns `json` columns as raw
  strings here, so `Reading#data` and `Inverter#latest_values` declare
  `attribute …, :json`. Keep that when adding JSON columns, and write fixtures as
  nested YAML (not pre-stringified JSON) to avoid double-encoding.
- **Shared installation.** No per-user scoping of inverters; every account is an
  admin. API tokens are per user.
- **Registration is bootstrap-only.** Public sign-up works only while `User` has no
  rows (first-admin bootstrap on a fresh deploy); once any user exists,
  `RegistrationsController` closes it and accounts are created via `UsersController`
  (the Users admin page). `registration_open?` helper drives the sign-in link. Don't
  reopen public registration. Self-deletion and last-account deletion are blocked.

## Layout / where things live

- MQTT subscribe loop (own process): `app/models/mqtt/listener.rb`, run by
  `bin/mqtt-listener` (in `Procfile.dev` as the `mqtt` process; `Procfile` for prod).
- Ingestion + snapshot + status: `app/models/inverter.rb`.
- Live dashboard broadcasting: `app/models/concerns/broadcastable.rb`.
- Payload accessors: `app/models/reading.rb` (`value_for`/`unit_for`, scopes).
- Solis-style overview presenter: `app/models/inverter/snapshot.rb` (`Inverter::Snapshot`
  — live power flow + state + today energy, all display-ready) and
  `Inverter#intraday_series` for the chart. Dashboard panel partials live in
  `app/views/inverters/_panel|_live|_power_flow|_battery_card|_self_consumption|_today_energy|_intraday`.
- Energy history + costs: `DailySummary` rolls the agent's cumulative `today_*`
  counters into one row per `(inverter, date)` — maintained on every reading via
  `Inverter#record_daily_summary` (running max). `EnergySummary` (PORO, takes any
  `DailySummary` relation + period + date) computes the range, summed
  `Inverter::EnergyTotals`, breakdown series, and nav labels — reused by both
  `inverters#show` (per-inverter, `_aggregates`) and `dashboards#show` (site-wide
  `DailySummary.all`, `dashboards/_summary`), each in its own Turbo frame
  ("aggregates" / "dashboard_aggregates"). Shared markup: `inverters/_period_nav`
  (parameterized by a `link` lambda), `_energy_totals`, `_cost_cards`. `Tariff`
  (singleton) turns kWh into money (`cost`/`earnings`/`net`/`savings`). The unique
  `(inverter_id, date)` index also serves the range/grouping queries.
  Note: `Inverter#intraday_series(date:)` is date-scoped (the Day tab respects the
  selected date — not a rolling 24h). Summaries build forward from when the server
  starts ingesting; `Inverter#rebuild_daily_summaries!` recomputes from readings.
- Broker settings: `app/models/mqtt_config.rb` (singleton via `.instance`).
- API: `app/controllers/api/v1/*` + `ApiTokenAuthentication` concern + Jbuilder views.
- Web/admin: `Dashboards`, `Inverters`, `MqttConfigs`, `ApiTokens`, `Registrations`
  controllers; views are Tailwind utility classes (components via `@apply` in
  `app/assets/tailwind/application.css`).
- PWA: routes for `manifest`/`service-worker`, `app/views/pwa/*`, registered from
  `app/javascript/application.js`.

## Essential commands

```bash
bin/dev                 # web + mqtt-listener + tailwind watch (foreman / Procfile.dev)
bin/rails test          # minitest
bin/rubocop             # rails-omakase
bin/rails db:prepare

# Dev against any MQTT broker on localhost:1883 (e.g. ghrian-agent's dev mosquitto,
# https://github.com/zavan/ghrian-agent — clone it alongside this repo):
make dev-up        # (in a ghrian-agent clone) mosquitto on localhost:1883
make dev-pub       # (in a ghrian-agent clone) publish one sample reading
```

## When an AI agent works on this code

1. Run `bin/rails test` and `bin/rubocop` after edits.
2. Add/adjust ingestion behavior on the models, never in a service object.
3. Keep the payload contract in lockstep with the agent (`{value,unit,label}` +
   `_active`). If the agent's shape changes, follow it here.
4. New accessory/metric handling is data-driven from the payload — don't hard-code
   register names; the dashboard tiles pick keys from `latest_values`.
5. Never introduce inverter writes or MQTT publishes. Read-only.
6. Keep the listener resilient (reconnect, config-change reload) and a separate
   process from Puma.

Keep this file up to date when you make significant changes.
