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
  the DSN from credentials and sends the check-in as a Sentry **envelope**
  (`POST /api/<project>/envelope/` — the transport sentry-cli/SDKs use; the
  plain `cron` HTTP endpoint accepts with 202 but drops on this org). No DSN
  on the host → silent no-op (exit 0).

## ⚠️ Platform behavior: API-created monitors land `disabled` (measured 2026-09-12)

Monitors created via the API **and** via envelope check-in upsert are born
`ObjectStatus=disabled` on this org (crawlr's parallel test monitors showed
the identical pattern). A disabled monitor **drops** check-ins until it is
enabled once in the Sentry UI: **Crons → <monitor> → enable** (there is no
working API path — `PATCH status` → 403 with this token; the token has
`alerts:write`/`project:admin`). The one per-project monitor that is active
today (`crawlr-identify-duplicates-hourly`) was created via the UI. After the
one-time enable, envelope check-ins process normally (verified: check-ins
registered against the active crawlr monitor with `lastCheckIn` updating).
Re-verify after enabling:
`curl -H "Authorization: Bearer $SENTRY_ACCESS_TOKEN" \
  https://sentry.io/api/0/organizations/tim-lawrenz/monitors/tgenetics-dev-worker/`
→ expect `"status": "active"` and `environments[0].lastCheckIn` populated
after the next real check-in.

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
"Cron Monitor missed" issue → triage below. (Until a monitor has been enabled
once in the UI — see above — its check-ins are dropped, so enable all three
after provisioning; the first real cron tick then populates `lastCheckIn`.)

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

Create the project (API) and monitors **via a check-in envelope** (the only
auto-creation path — created monitors land `disabled`; enable each once in the
Sentry UI after creation):

```bash
# 1. project
curl -X POST https://sentry.io/api/0/teams/tim-lawrenz/tim-lawrenz/projects/ \
  -H "Authorization: Bearer $SENTRY_ACCESS_TOKEN" \
  -d '{"name":"t-genetics","slug":"t-genetics","platform":"ruby-rails"}'

# 2. DSN from the project keys -> write into credentials on the host:
#      EDITOR="cp /tmp/creds.yml" bin/rails credentials:edit
#    (creds.yml: sentry: { dsn: https://<key>@o213028.ingest.us.sentry.io/<project> })

# 3. create monitors via envelope check-in (upstream of any real cron tick)
bin/sentry_checkin tgenetics-dev-worker start && bin/sentry_checkin tgenetics-dev-worker ok
bin/sentry_checkin gaas-product-manager  start && bin/sentry_checkin gaas-product-manager  ok
bin/sentry_checkin gaas-founder-digest   start && bin/sentry_checkin gaas-founder-digest   ok

# 4. ENABLE each in the Sentry UI: Crons -> <monitor> -> enable
#    (API-created monitors are ObjectStatus=disabled and drop check-ins until
#     enabled once; there is no working API activation — PATCH is 403)

# 5. verify
curl -H "Authorization: Bearer $SENTRY_ACCESS_TOKEN" \
  https://sentry.io/api/0/organizations/tim-lawrenz/monitors/?project=t-genetics
```

Check-ins then flow automatically from `bin/sentry_checkin` (no token needed
at runtime — the DSN in the envelope authorizes it).

## Acceptance counters (pending item)

Pillar promises pipeline acceptance counters (accepted/rejected per cycle) so
pipeline health is a dashboard. `bin/publish_prd` is the current ingestion
point; add counter emission when the pipeline grows a real render/acceptance
stage (see AGENTS.md).