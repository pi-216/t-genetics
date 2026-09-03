# PRD-0005 — Token API for machines

## Summary
Org-scoped **API tokens** let machines CRUD chromosomes and run the experiment
loop over HTTP: create experiment → request suggestion → report outcome.
Tokens are created by owners, scoped to an org, and authenticate via a Bearer
header. The existing rswag/OpenAPI surface (already specced) is the skeleton;
this PRD makes it org-scoped and token-auth'd.

## Problem / motivation
The product's core workflow is machines reporting fitness (ML pipelines, eval
harnesses, test runners). Those machines can't use browser sessions. A
credentialed HTTP API with org isolation is the difference between "a web toy"
and "a service agents can drive." Tokens are also the foundation the MCP server
will sit on (deferred until this API is live).

## Goals / Non-goals
- Goals: org-scoped token model (owner-created, rotatable, revocable), Bearer
  auth middleware, chromosome CRUD + experiment loop endpoints, OpenAPI docs
  regenerated and verified.
- Non-goals (Out): token scopes/fine-grained permissions (flat — owner ruling),
  per-token rate limiting (later), OAuth2/PKCE (later), MCP server (deferred
  until this API is live), webhook delivery of evolution events (later),
  billing metering (red line until first payer).

## Scope — In / Out
**In:** `ApiToken` model (org_id, name, token digest, created/revoked_at,
last_used_at); token generation (owner UI + maybe a rake task); authenticate
with `Authorization: Bearer <token>`; `current_org` from token; endpoints
(namespace `/api/v1`): chromosomes (index/show/create/update/destroy, nested
alleles), experiments (create, show, index), suggestion (POST
`/experiments/:id/suggestions`), outcome (POST
`/performance_logs/:id/outcome` or nested under suggestions); rswag specs +
`swagger/v1/swagger.yaml` regenerated + `rswag:verify` green.
**Out:** everything under Non-goals.

## Acceptance criteria
- An owner can create a token (name + org), see it once (plaintext only at
  creation), copy it, and revoke it; revocation kills auth immediately.
- A member cannot create/revoke tokens (owner-only) but CAN use the API with a
  valid token.
- Token auth → org scoped; cross-org access returns 403/404.
- Chromosomes: full CRUD via API (matching web designer behavior).
- Loop: create experiment → request suggestion (returns organism values) →
  report ONE fitness outcome → evolution continues as in PRD-0003.
- Invalid/missing/revoked token → 401; malformed payloads → 422 with error
  keys; idempotent-safe where contracts allow.
- OpenAPI artifact verified (`bundle exec rake rswag:verify`).
- Spec'd via request specs + BDD; `bin/verify` green.

## Edge cases & red lines
- Tokens stored as **digests only** (never plaintext in DB); plaintext shown
  once at creation.
- Revocation takes effect immediately (no refresh window).
- Tokens die with the org: org deletion (deferred) must revoke all tokens;
  member removal revokes member-created tokens (they don't exist — owner-only —
  but member-issued API use is tied to membership: removing a member must
  deactivate their API access, see PRD-0002 interplay).
- Never expose fitness evaluation or user-supplied code execution (red line —
  sandbox rule for anything that could run customer code).
- Rate limiting: skip for v1 but log token usage (last_used_at).

## Metrics / definition of done
- Request specs for every endpoint (201/200/401/403/404/422 paths); BDD green;
  `bin/verify` green.
- OpenAPI artifact in sync (rswag:verify green in CI).
- Agent walkthrough: create token → curl a full loop (create chromosome →
  experiment → suggestion → outcome) with the token.

## Open questions (product owner)
- **A1 Token UI:** owner page under org settings (recommend) vs. only-rake.
- **A2 Naming/paths:** `/api/v1` prefix + resource names — confirm the
  OpenAPI artifact's current paths (they may already define a compatible
  shape — align rather than invent).
- **A3 Suggestion/outcome payload shape:** confirm the exact request/response
  (existing rswag specs define the intent — this PRD reconciles them with org
  scoping + tokens).

## Related
- PRD-0002 (orgs/tokens ownership).
- PRD-0003 (the loop — same commands, HTTP surface).
- MCP server (deferred — wraps this API later).