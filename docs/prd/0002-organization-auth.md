# PRD-0002 — Organization sign-up & authentication

## Summary
Email+password accounts organized into **organizations** (orgs). Sign-up creates
an org with the founder as **owner**; owners can invite additional members by
email. Roles are **flat**: owner (billing/members/tokens) and member (use the
workspace). Every experiment/chromosome belongs to an org; members only see
their own org's data. This is the multi-tenant foundation the whole product
builds on.

## Problem / motivation
The product is a service where teams test organisms against their own fitness
function. That requires: durable identities, a billing boundary (one per org),
and isolation between customers. Without orgs, every new user is a data island
and "one billing setup per customer" (the gate) is impossible.

## Goals / Non-goals
- Goals: sign-up creates org + owner; sign-in/out; owner invites members;
  flat owner/member roles; org-scoped data isolation; email+password auth.
- Non-goals (Out): granular permissions/access rights (ruled out by founder —
  flat roles only), magic-link auth (defer), password reset (defer), 2FA,
  email verification (defer), social login, org branding/theming, org
  deletion/transfer (defer), billing capture (red line until first payer).

## Scope — In / Out
**In:** `Organization`, `OrgMembership` (role: owner|member), `User`;
registration creates org (name + first user as owner); session auth
(email/password, bcrypt); owner-only invite-by-email (link or code) →
membership; org switcher not needed (single org per user for v1 — see A2);
ownership scoping of all domain records (`experiments.*_belongs_to :organization`).
**Out:** everything under Non-goals.

## Acceptance criteria
- A visitor signs up → org + owner user created, signed in immediately.
- Duplicate email rejected with a clear message; password hashed (bcrypt).
- Sign-in with valid creds succeeds; invalid fails safely; sign-out terminates session.
- Owner can invite a member by email; invitee joins the org as `member`.
- Owner can add/remove members (removal prevents sign-in to that org).
- A member cannot manage billing, members, or tokens (owner-only).
- Org A's user cannot see/read/write org B's chromosomes or experiments
  (authorization enforced server-side + on every domain query).
- All domain tables gain a non-null `organization_id` (migration with backfill
  for existing rows — see Edge cases).
- Owned by a new `packs/identity` pack; all mutations through Commands.

## Edge cases & red lines
- **Existing data:** current rows lack orgs. Migration must backfill a
  "default" org (single-tenant legacy) before adding the constraint — founder
  approval of the backfill org's fate (archive vs. migrate to a real org) is
  required in the migration change (dev data only today — low risk, still
  review-flagged).
- Roles are flat — no resource-scoped rights, no custom roles (founder ruling).
- Owner removal: an org must never end up with zero owners (guard: last owner
  cannot be removed/demoted).
- No real-person likeness; **no external sends** — v1 invites are
  owner-generated shareable codes (no outgoing email, keeps the red line).
  Email-link invites deferred until mail infra + founder sign-off.
- Member removal must revoke tokens too (see PRD-0005 interplay).

## Metrics / definition of done
- Command + request + model specs green; BDD green; `bin/verify` green.
- Authorization matrix spec: for every org-scoped route, a cross-org request
  returns 403/404.
- No plaintext password anywhere in codebase/tests.

## Open questions (product owner)
- **A1 Auth:** email+password confirmed (founder ruling 2026-09-02).
- **A2 Org per user:** allow one org per user for v1 (simplest) or multiple
  memberships? (Recommend: one org per user for v1; multiple memberships later.)
- **A3 Invite flow:** email link (needs mailer) vs. invite code shown to owner?
  (Recommend email link if we have SMTP; else code.)
- **A4 Org naming:** org display name from sign-up form (recommend yes, free text).

## Related
- PRD-0001 (landing CTA → sign-up).
- PRD-0003/0004/0005 — all consume org scoping and the `packs/identity` pack.