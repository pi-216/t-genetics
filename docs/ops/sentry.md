# Sentry operations — t-genetics (GAaaS engine)

How the Sentry pillar (AGENTS.md) is wired on this repo and how to operate it.
Pillar: SDK + releases + cron check-ins + blast-radius triage + acceptance
counters. Sentry is the observability substrate for the venture, not an add-on.

## Wiring (what the code does)

- `config/initializers/sentry.rb` — `sentry-ruby`/`sentry-rails` init.
  - DSN read from **encrypted Rails credentials** (`config/credentials.yml.enc`
    → `sentry: { dsn: ... }`), never env or the repo. No DSN → SDK disabled.
  - Enabled environments: `development production staging`. `development` is
    included **on purpose**: the live host serves the app with
    `RAILS_ENV=development` (bin/run_server.sh), so a prod-only allowlist
    would mute the live site. Only hosts carrying the credentials file send.
- `bin/run_server.sh` — exports `SENTRY_RELEASE=$(git rev-parse --short HEAD)`
  before boot; issues land on the deploy's release, resolved-on-release closes
  them automatically.
- `bin/sentry_checkin <slug> <start|ok|failed>` — cron check-in helper. Reads
  the DSN from credentials, sends an HTTP check-in to the ingest cron endpoint
  (host/key/project derived from the DSN — no token at runtime). No DSN on
  the host → silent no-op (exit 0).

## Cron monitors (missing tick = alert)

Monitors are upserted on first check-in; create/edit them with the expected
interval so a silently-paused job fires the missing-tick alert
(Expected-Event Absence Detection — a paused cron must alert, not rot).

| Monitor slug             | Job                  | Schedule        | Expected interval |
|--------------------------|----------------------|-----------------|-------------------|
| `tgenetics-dev-worker`   | tgenetics-dev-worker | `0 * * * *`     | 60 min            |
| `gaas-product-manager`   | gaas-product-manager | `0 9 * * *`     | 24 h              |
| `gaas-founder-digest`    | gaas-founder-digest  | `30 8 * * *`    | 24 h              |

The cron prompts call `bin/sentry_checkin <slug> start` at run start and
`... ok|failed` on completion (workdir = repo). The **start** check-in is the
absence signal; a job that never runs never sends one → Sentry opens a
"Cron Monitor missed" issue → triage below.

## Triage path (new issue → GitHub issue)

1. **New Sentry issue** (error spike or missed check-in): read blast radius
   first — events, affected users, first/last seen, Seer root cause:
   `curl -H "Authorization: Bearer $SENTRY_ACCESS_TOKEN" \
   https://sentry.io/api/0/issues/<ISSUE_ID>/` (and `/events/latest/` for the
   stacktrace; attach breadcrumbs as evidence).
2. **Suggested severity** (grounded matrix): P1 = live workflow blocked/data
   loss (org-scoping leak, fitness-input corruption); P2 = main path erroring
   for many users; P3 = isolated/rare/observability-only; P4 = cosmetic.
3. **Draft a GitHub issue with the evidence** — title = issue title + Sentry
   link, body = blast radius (events/users/first-seen), stacktrace excerpt,
   suggested severity, `bug` label. **A human approves creation** (Tim, via
   the founder digest) — never auto-create.
4. Bug-labelled issues flow through the normal board → worker pipeline
   (approved = release switch).

## Provisioning (one-time, needs founder OK — external write)

Create the project and monitors via API (token: Sentry MCP env in
`~/.hermes/config.yaml`):

```bash
# project
curl -X POST https://sentry.io/api/0/teams/tim-lawrenz/tim-lawrenz/projects/ \
  -H "Authorization: Bearer $SENTRY_ACCESS_TOKEN" \
  -d '{"name":"t-genetics","slug":"t-genetics","platform":"ruby-rails"}'

# DSN from the project response → write into credentials on the host:
#   EDITOR="cp /tmp/creds.yml" bin/rails credentials:edit   (creds.yml has sentry.dsn)

# monitors (repeat per row above; update schedule to the crontab)
curl -X POST https://sentry.io/api/0/organizations/tim-lawrenz/monitors/ \
  -H "Authorization: Bearer $SENTRY_ACCESS_TOKEN" \
  -d '{"project":"t-genetics","name":"tgenetics-dev-worker","slug":"tgenetics-dev-worker","type":"cron_job","config":{"schedule_type":"crontab","schedule":"0 * * * *","checkin_margin":10,"max_runtime":50,"failure_issue_threshold":1}}'

# verify
curl -H "Authorization: Bearer $SENTRY_ACCESS_TOKEN" \
  https://sentry.io/api/0/organizations/tim-lawrenz/monitors/?project=t-genetics
```

Check-ins then flow automatically from `bin/sentry_checkin` (no token needed
at runtime — DSN auth).

## Acceptance counters (pending item)

Pillar promises pipeline acceptance counters (accepted/rejected per cycle) so
pipeline health is a dashboard. `bin/publish_prd` is the current ingestion
point; add counter emission when the pipeline grows a real render/acceptance
stage (see AGENTS.md).