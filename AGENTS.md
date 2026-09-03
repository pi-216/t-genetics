# AGENTS.md — t-genetics (pi-216)

Governance hub for AI agents (autonomous workers, reviewers, assistants) working
in this repo. **Pipeline first:** the commercial product ships through the
PRD → board → worker loop. Read this whole file before coding.

## The product & red lines

t-genetics is the GAaaS engine: a genetic-algorithm evolution loop as a served
product. **Suggest an organism to test → customer tests on their own infra →
reports ONE fitness number → we breed offspring → repeat.** We never run or
evaluate anyone's fitness function.

- **Never evaluate fitness for anyone.** The only fitness-bearing input is the
  customer-reported number (`fitness_input_value` on `PerformanceLog`).
- **No paid-tier feature build before one paying customer.** Billing capture,
  exploitation/greed controls, and generation-progress insights are deferred.
- **Flat roles only** (owner/member per org) — no granular permissions, ever.
- **Org-scoped everything** — every domain record belongs to an organization;
  cross-org access must return 403/404, never data.
- **No real-person likeness/voice** in any output; sandbox anything that
  executes user-supplied code.

## The loop & pipeline (how work ships)

1. PRDs live in `docs/prd/000N-slug.md` (+ matching Gherkin feature spec in
   `gherkin_specs/<domain>/<slug>.feature`).
2. `bin/publish_prd <PRD.md> <feature.feature>` → creates the epic + one issue
   per Scenario on the **pi-216 org board — Project 2 (t-genetics)**,
   Status=Todo, label `ticket`. Idempotent.
3. Tickets are NOT worked until the product owner adds the `approved` label.
4. The dev worker claims exactly ONE `approved`+`ticket` issue per run
   (Status Ready/In progress + `agent_working`), implements TDD, opens a PR
   with body `Closes #N`, never merges itself.
5. Every commit must pass `bin/verify` (Tier-0 gate, fail-closed).

Board: https://github.com/orgs/pi-216/projects/2 ·
Pipeline config: `config/autonomous/pipeline.yml`

## Stack & conventions

- Ruby 3.4.5, Rails 8.1.1, PostgreSQL, RVM-active shell → always `bundle exec`,
  never `bash -l -c`.
- **Command pattern:** business logic lives in `GLCommand` commands (root
  `app/commands` + `packs/experiments/app/commands`). Controllers: auth →
  validate → call command → render result. No fat models, no direct model
  mutation in controllers.
- **Side effects** (broadcasts, external writes) fire only after the DB commit
  (`run_after_commit`) — never inline, never model callbacks.
- **Packwerk boundaries:** domain packs under `packs/` (currently
  `packs/experiments`). A pack must declare `dependencies:` before reaching
  into another pack; root package `"."` provides ApplicationRecord/Command/
  Controller. `packwerk check` stays green.
- **Migrations:** schema-only; data backfills go in rake tasks; safe
  multi-phase column changes. `strong_migrations` enforced at migrate time.
- **UI:** server-rendered + ViewComponents + HAML, Hotwire (turbo/stimulus),
  Tailwind. No new heavy JS framework without review.
- **API docs:** rswag; regenerate `swagger/v1/swagger.yaml` with
  `bundle exec rake rswag:specs:swaggerize`; keep it verifiable
  (`bundle exec rake rswag:verify`).
- **Tests:** RSpec (no controller specs — thin request specs + command specs +
  model specs + component specs). BDD features under `gherkin_specs/`
  (Cucumber). Factory truth in `spec/factories/` — never guess factory names
  or fields; read the factory.

## The core domain (already built — extend, don't duplicate)

- `Chromosome` → `Allele` (Float/Integer/Boolean/Option polymorphic) → `Value`s.
- `Generation` → `Organism` (a chromosome's values) → generations evolve.
- `packs/experiments`: `Experiment` (chromosome + population + thresholds) +
  `PerformanceLog` (a suggested organism + the reported outcome) + the loop
  commands: `Experiments::RequestSuggestion` → `RecordOutcome` →
  `EvaluateAndEvolve` (auto when `ripe_for_evolution?`), `Setup`.

## Verification — `bin/verify` (Tier-0 gate, fail-closed)

Runs: rubocop · brakeman -z · bundler-audit · packwerk · erb_lint · rspec ·
cucumber · rswag:verify · gherkin_lint (if `.feature` files exist). Any failure
→ exit non-zero; do NOT commit. For counts, run each step separately with real
exit capture (`bundle exec X > /tmp/x.log; echo $?`), never `X | tail; echo $?`.

After a pull, check BOTH DBs for pending migrations:
`bundle exec rails db:migrate:status` AND
`RAILS_ENV=test bundle exec rails db:migrate:status` — grep for `down`.
Dev DB migrated by the agent; test DB routinely lags behind.

## BDD conventions

- `.feature` files: `@PRD-000N` feature tag, per-scenario `@DEV-NNNN` tags;
  drift-flag comment in the header when the feature diverges from the PRD.
- Unimplemented scenarios stay `@wip` — `--strict` cucumber profile fails on
  undefined steps otherwise.
- `gherkin_lint` takes individual files, NOT directories (`Errno::EISDIR`).
  Invoke as `bin/verify` does: `bundle exec gherkin_lint $(ls gherkin_specs/**/*.feature)`.
- One action per scenario (gherkin_lint `AvoidScripting`).

## Working here (git rules)

- Never `git checkout main` if another worktree owns it — branch from the
  remote: `git fetch origin && git checkout -B <branch> origin/main`.
- Re-derive PIDs/ports before acting (`ps aux | grep puma`, `ss -tlnp`) —
  remembered PIDs go stale.
- No secrets in this repo, ever — `config/credentials.yml.enc` +
  `master.key` stay gitignored; token digests only in the DB (PRD-0005).
- PRs are opened by the worker or the product owner — never merge your own PR
  without a `[verified]` review pass.

## References

- PRDs: `docs/prd/` · Design sprint: `docs/design-sprint.md` · Venture
  orientation: `/home/tim/Documents/obsidian/04 - projects/ideas/gaas/HANDOFF.md`
- The t-chat pipeline this mirrors: see the `t-chat-development` Hermes skill
  (pi-216/t-chat) for the full autonomous-pipeline ops runbook.