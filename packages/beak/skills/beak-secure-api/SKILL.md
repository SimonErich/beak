---
name: beak-secure-api
description: >-
  Restrict who can see or change what in a Beak app's API: sessions and
  roles, per-model read/write/delete access, row scoping ("users only see
  their own"), server-owned read-only fields, per-role actions and hidden
  columns, plus matching panel permissions for presentation, proved by
  per-role API tests. Use for roles, tenants, "hide this column", read-only
  access, or before production. The server policy enforces; panel permissions
  only hide UI. Not for Serverpod-backed panels, where the Serverpod endpoint
  scopes enforce access (beak-serverpod-setup).
---

# Secure the API

A fresh Beak server allows everything (`BeakAllowAllPolicy`) so that a panel
works with no setup. Production replaces that with `BeakPolicies`: one
`BeakModelRules` per model, and everything not listed is denied. A model with no
rule is invisible: 401 to an anonymous request, 403 to anyone else, and no other
model's relationship exposes it.

Read first, by path: `.dart_tool/beak/docs/backend/auth-and-policies.md`,
`.dart_tool/beak/docs/shipping/security.md` and
`.dart_tool/beak/docs/panel/auth-and-idle-lock.md`.

## Steps

1. If `lib/server.dart` is missing, run `beak eject server`, then `beak prepare`
   to wire it. The file returns `defaults.build(...)`; every argument is
   optional.
2. Name the roles. Roles are strings on a `BeakPrincipal(id:, roles: {...})`.
   Give them names in one place and build access values from them:
   `const staff = BeakAccess.role('staff');`, combined with `BeakAccess.any([...])`,
   `.all`, `.not`, `BeakAccess.authenticated` and `BeakAccess.anyone`.
3. Give the server a way to sign in. Pass `authSessions: BeakAuthSessions(store:
   ..., secret: ..., users: [BeakUserAccount(...)])` to `defaults.build`. It
   mounts `POST /api/auth/login`, `/api/auth/logout` and `GET /api/auth/me`, and
   the request guard follows the same store. Read the secret from
   `defaults.environment`, never from source, and never commit a password:
   `passwordHash` is `hashBeakPassword(password, secret: secret)` computed
   outside the code. `InMemoryTokenSessionStore` forgets sessions on restart;
   use a durable `TokenSessionStore` in production.
4. Write the rules, `policy: BeakPolicies(rules: [...])`, one `BeakModelRules`
   per model: `read:`, `write:` (create, update, relations, uploads), `delete:`,
   `rowScope: (principal) => OrderModel.userId.eq(principal.id)` (a typed filter
   applied to every read and write, so a filter chosen by the client cannot
   widen it; return `null` for "every row"), `readOnlyFields: {...}` (values the
   server owns; a client that sends one gets a 422) and
   `actions: {InvoiceActions.issue: BeakAccess.role('billing')}`. List every
   model the panel touches, related models included.
5. Hide a column from some roles, or refuse writes to it? `BeakPolicies` cannot
   do that. Wrap it in a small class that implements `BeakFieldPolicy`
   (`references/field-policy.md`). Reads, filters, sorts, search, aggregates
   and exports then treat the field as absent.
6. Mirror the rules for presentation only. On the schema class,
   `static BeakPermissions get permissions => BeakPermissions({...})` hides
   buttons by operation; `BeakResource(canCreate:, canEdit:, canDelete:)` does
   the same per resource. Neither protects anything: a client that skips the
   panel skips them.
7. Prove it with per-role API tests, denials first: anonymous, a role with too
   little, a role with enough. Cover query, get, create, update, delete, export,
   aggregate and a graph commit; a denied commit returns `complete == false`
   with the error in its outcome. The recipe is in `references/policy-tests.md`.
8. Check the leaks by hand: `beak doctor`, that `.env` is git-ignored, that
   CORS (`corsOrigin:` in `defaults.build`) names the panel's origin instead of
   `*`, and that no model the policy forgot is meant to be public.

## Gate

The role tests pass, `beak doctor`, `dart format .`, `flutter analyze` and
`flutter test` are clean, and each rule has a test that fails when the rule is
loosened.

## Example prompt

```text
Use the beak-secure-api skill: support staff read only their own company's orders and never see cost prices; admins see everything. Prove it with API tests for query, export and aggregate.
```
