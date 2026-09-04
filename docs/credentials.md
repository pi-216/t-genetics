# Credentials policy

Founder ruling on **issue #58 (2026-09-04)**: option 2 — encrypted credential
files are **intentionally unused** in this repo. Secrets come from the
environment (`SECRET_KEY_BASE`, pinned in the `tgenetics-puma` systemd unit);
token digests live only in the DB (PRD-0005).

## Current state

- `config/credentials.yml.enc` was removed from the repo on 2026-09-04.
  Verified before deletion: it held only the scaffold-generated defaults from
  the original 2023-12-06 commit (`fcc3285` "we want an app", 456 bytes,
  never modified on `main`, never referenced by the app; `require_master_key`
  is off, no model uses Active Record encryption). The scaffold blob remains
  in git history — no real secrets, so no history rewrite was performed.
- `/config/credentials.yml.enc` and `/config/master.key` are gitignored and
  must never be tracked again.
- `bin/rails credentials:edit` is intentionally non-functional (no master key
  exists on disk). Do not re-add credential files without a founder ruling.

## Proposed AGENTS.md clarification (human apply)

Autonomous workers are blocked from editing AGENTS.md, so this line is
proposed for a human to paste into the "Working here (git rules)" section,
replacing the current "No secrets" bullet:

```markdown
- No secrets in this repo, ever — secret material lives in the environment
  (`SECRET_KEY_BASE`) and in the DB (token digests only, PRD-0005).
  Credentials tooling (`bin/rails credentials:edit`) is intentionally unused;
  encrypted credential files are untracked and gitignored
  (issue #58 ruling, 2026-09-04).
```
