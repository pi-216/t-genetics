# PRD-0007 — API token management (web UI)

## Summary
A dedicated org-settings web surface where owners manage the API tokens that
authenticate the RESTful JSON API (PRD-0005): see every token — active and
revoked — with its metadata, create a token with a one-time plaintext reveal,
and revoke a token with immediate effect. Replaces the bare create-form +
`<li>` list currently embedded in the settings page with a real management
interface, reachable from the signed-in navigation.

## Problem / motivation
PRD-0005 shipped the token model and a minimal owner surface: a create form
and a one-time plaintext flash on the org settings page, plus a bare list of
active token names. Owners can mint tokens but cannot operate on them
afterwards: there is no way to see which integration a token belongs to, when
it was last used, or to revoke a leaked credential — the single most
important control for machine credentials. The model already carries
`revoked_at` and `last_used_at`; the web interface surfaces neither.

## Goals / Non-goals
- Goals: a dedicated token management page (list all tokens + metadata +
  status), one-time plaintext reveal + copy on create, owner-only revoke with
  immediate effect, empty state, signed-in nav entry, last-used display.
- Non-goals (Out): token scopes/expiry/rate limits (flat — PRD-0005 ruling),
  token rotation/re-issue of a name (revoke + recreate is the v1 path),
  rename-after-create (pending ruling below), member management of tokens
  (owner-only), OAuth/PKCE/MCP (deferred).

## Scope — In / Out
**In:** `Identity::ApiTokensController` gains `index` + `revoke` (owner-only,
POST); a dedicated management page listing every org token (name, created_at,
last_used_at, active/revoked status); the create form moved onto it with the
one-time plaintext reveal (existing flash semantics) + a copy affordance;
revoke confirmation; empty state; signed-in nav link; the settings page's
token section reduced to a link to the new page. Request specs + component
specs + BDD (`@javascript` for the browser scenarios).
**Out:** everything under Non-goals.

## Acceptance criteria
- The owner can open a dedicated token management page listing every org
  token — active and revoked — with name, created date, last-used date, and
  status.
- The page is reachable from the signed-in header navigation.
- Creating a token shows the plaintext exactly once with a copy affordance;
  the new token appears in the list.
- Revoking an active token marks it revoked in the list and kills API auth
  immediately (existing `TokenAuthentication` behavior, unchanged).
- A member receives a forbidden response when requesting token management;
  no token is created or revoked by a member.
- An org with no tokens sees an empty state that routes to creating the first
  token.
- `bin/verify` green (incl. rswag, gherkin_lint, and the `@javascript` gate).

## Edge cases & red lines
- Plaintext token is shown exactly once at creation and never persisted —
  revocation and all list rendering work on the digest/name only.
- Revocation is immediate: no refresh window, no grace period.
- Owner-only management (flat roles — PRD-0005/0002 ruling); a member cannot
  see or manage tokens.
- The page renders only `current_organization` rows; cross-org access returns
  403/404 — never another org's token data.
- No real-person likeness/voice and no fitness evaluation (unchanged red
  lines). No token or digest ever leaves the org's own page.

## Metrics / definition of done
- Request specs for `index` (200/403) and `revoke` (success/403); component
  specs for the list, status badges, and empty state; BDD scenarios green
  under the browser driver.
- Agent walkthrough: sign in as owner → open tokens page → create → copy →
  use the token against `/api/v1` → revoke → the same token now answers 401.
- `bin/verify` green.

## Open questions (product owner)
1. **Token identity prefix:** store the first 8 chars of each plaintext at
   creation and show it in the list so owners can recognize an integration
   without relying on names alone? (Recommend yes — a small `token_prefix`
   column; digest-only storage is unaffected.) Otherwise names alone identify
   tokens.
2. **Settings-page token section:** move token management fully onto the new
   dedicated page (settings keeps only a link), or keep the inline create
   form too? (Recommend: dedicated page only — one surface.)
3. **Rename after create:** support renaming a token later? (Recommend no for
   v1 — revoke + recreate, consistent with flat tokens.)

## Related
- PRD-0005 (token model + machine API; this PRD is its management surface).
- PRD-0002 (org settings, owner/member flat roles).
