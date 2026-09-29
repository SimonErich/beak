# Further declarative framework improvements

Research date: 2026-09-27. Sources are official framework documentation accessed
on that date. This is a design note, not a description of implemented Beak APIs.
The audit below records the starting point before implementation. For current
APIs, use the maintained guides linked here rather than the proposal vocabulary.

## Implemented contracts

- [Model behavior](../models/behavior.md): initial values, suggestions,
  derivations, snapshots, dependency ordering and lifecycle guards.
- [Actions](../panel/actions.md): model commands shared by forms and tables,
  typed arguments, transactional validation, receipts and account capabilities.
- [Relationships](../models/relationships.md): inferred eligibility and resource
  presentation defaults, owned drafts and typed candidate graphs.
- [Drafts and review](../forms/drafts-and-review.md): storage, conflict resolution,
  review and an explain inspector around the existing form session.
- [Imports and bulk edits](../forms/imports-and-bulk-edits.md): validation previews,
  revisions, cancellation and per-record receipt recovery.
- [Dynamic attributes and variants](../models/dynamic-attributes-and-variants.md):
  shared descriptors, reconciliation and bounded combination staging.

The final design uses ordinary typed layout fragments and `BeakFormSections`
for presentation reuse, without a second inheritance hierarchy. External side
effects remain application-owned, as the transaction boundary below requires.

The most valuable next step is to make application intent reusable across every
surface: a business rule should not need separate implementations in a form, a
table action, an API handler and a background job. Keep three responsibilities
clear: models describe data and invariants, actions describe business operations,
and screen configuration describes presentation. The framework supplies their
execution lifecycle.

## Pre-implementation audit

A parallel repository audit found that the foundation already includes input
derivations with tracked dependencies and cycle detection, relationship-query
refresh with invalid-selection handling, modal draft checkpoints, conflict
timestamps and recoverable commits. These mechanisms should be reused, not
replaced with a second implementation.

- `BeakInput.derive` is currently attached to a form placement; the proposed
  addition is a reusable model-level value lifecycle shared with authoritative
  writes. See `packages/beak_frontend/lib/src/form/beak_form_layout.dart` and
  `beak_form_session.dart` in the same directory.
- `BeakExists` with `BeakFieldMatch` already declares dependent relationship
  eligibility. The missing connection is deriving picker queries and
  prerequisites from that contract. See
  `packages/beak_core/lib/src/validation/beak_record_rule.dart`.
- Resource and row policies already enforce backend authorization. Field-level
  capabilities would extend these policies. See
  `packages/beak_backend/lib/src/auth/beak_policy.dart`.
- Ordinary Dart functions already reuse form sections, and typed queries are
  composable. Presentation profiles and named scopes should earn their place by
  removing repeated wiring rather than introducing a new inheritance system.
- `examples/clean_beak_config/lib/domain/shop_graph_preparer.dart` still supplies
  application-owned candidate-graph loading, reference resolution and patch
  assembly. A typed framework context could absorb that plumbing while retaining
  ordinary pure domain calculations such as `ShopTotals.calculate`.

Before adding contracts, migrate remaining example callbacks to existing shared
conditional, date-order and distinct-value rules. Use the remaining duplication
as the acceptance criteria for further framework work.

## 1. Named actions as the common execution contract

**Source finding.** Ash declares actions on resources, lets each action restrict
accepted attributes, and generates named calling interfaces. Its documentation
encourages intent-specific operations rather than routing every use case through
generic CRUD. It also distinguishes transaction and post-transaction phases.
[Ash actions](https://ash.hexdocs.pm/actions.html).

Filament actions combine a trigger, optional confirmation or input schema, and
execution. Built-in resource actions infer model policies; denial messages can
be displayed beside disabled actions.
[Filament actions](https://filamentphp.com/docs/5.x/actions/overview).

**Beak proposal.** Define `publish`, `issueInvoice`, `cancelOrder` or
`applyVoucher` once, with typed arguments, accepted fields, guards, effects and
result. Generate the client call and default action form. A page button, table
row, selection of rows or wizard completion should reference the same action.
Beak owns validation errors, pending state, duplicate-submission prevention,
receipts, retries and affected-view refresh. Ordinary create/edit remains the
zero-configuration action.

State transitions can then supply valid next actions and their explanations.
An issued invoice should not be editable through a generic update that bypasses
the action guard. Domain actions remain callable without any UI.

**Boundary.** A database transaction cannot undo an email or a captured payment.
Reactor explicitly separates retry/compensation for failed steps from undo for
successful steps whose later dependencies fail.
[Reactor error handling](https://reactor.hexdocs.pm/02-error-handling.html).
For Beak, use explicit durable after-commit work and idempotency contracts for
external effects; do not promise arbitrary automatic rollback. Begin with named
transactional actions before adding a general workflow engine.

## 2. Declared dependencies and reusable calculations

**Source finding.** Ash calculations can declare needed fields and related data.
Expression calculations can participate in filtering and sorting, while custom
calculations provide an escape hatch.
[Ash calculations](https://ash.hexdocs.pm/calculations.html).

Filament provides reactive fields, debounce/blur options, access to other field
values, update hooks and a separate submission transformation phase. These are
useful capabilities but require the configuration author to coordinate them.
[Filament form lifecycle](https://filamentphp.com/docs/5.x/forms/overview).

**Beak proposal.** Make dependencies a typed contract understood by the compiler:
customer determines eligible profiles; category determines attributes; quantity,
price and discounts determine line totals. The runtime derives subscription,
query and validation dependencies rather than requiring listeners.

Distinguish three operations: a default applied once, a suggested value that
stops following its source after manual editing, and a derived value that always
recomputes. Define what happens when a dependency changes: preserve a still-valid
selection, clear it, or mark it invalid. Debounce remote work and ignore stale
responses automatically. Detect dependency cycles and report the originating
configuration.

Use one pure calculation for draft previews and authoritative save preparation
where possible. A derived total should be usable in cards, tables, exports and
filters. A server-only calculation should explicitly advertise that capability
and return a preview result when the UI needs one. Historical invoice prices and
taxes need snapshot semantics, separate from live product values.

## 3. Relationship conventions that include the whole editing experience

**Source finding.** Filament repeaters load and save `HasMany` relationships on
form submission and support a declared ordering column. Its documentation warns
that editing a many-to-many pivot is different from editing the related entity.
[Filament repeaters](https://filamentphp.com/docs/5.x/forms/repeater).
Relationship selects can create or edit options using modal forms and select the
newly created record afterwards.
[Filament relationship selects](https://filamentphp.com/docs/5.x/forms/select).

**Beak proposal.** Put reusable lookup and presentation defaults on resources:
label, searchable fields, subtitle, thumbnail, compact form and detail preview.
A relationship input inherits these, including query loading, current-label
resolution and permission-aware create/edit actions. Override only the local
difference, such as profiles belonging to the current customer.

Owned children, shared entities and pivot records need explicit model semantics
with corresponding defaults for create, edit, detach, delete and ordering. Reuse
the same form fragment in full screens, relation tables and drawers. Nested
creation should join the parent draft by default where the ownership/transaction
contract supports it; an immediate independent save must be explicit so Cancel
has a predictable meaning.

## 4. Refresh and capabilities as resource infrastructure

**Source finding.** React-admin uses data-provider operation semantics to populate
record caches from list results and invalidate lists after writes. Its cache
documentation also explains why ordinary HTTP caching cannot know that a delete
invalidates a separate list response.
[React-admin caching](https://marmelab.com/react-admin/Caching.html).

React-admin asks a centralized `canAccess` provider before rendering standard
pages and action buttons. Ash also supports action and field policies, including
record-aware field visibility checks.
[React-admin authorization](https://marmelab.com/react-admin/Permissions.html),
[Ash policies](https://ash.hexdocs.pm/policies.html).

**Beak proposal.** Extend mutation receipts into one change stream used by lists,
detail pages, relationship labels, global search, aggregates and dashboard
queries. Track known relationship/calculation dependencies; use conservative
invalidation when they are unknown. Cache identities must include actor/tenant,
query and transport scope. Never overwrite an unsaved draft with a background
refresh; expose a version conflict with a useful comparison instead.

Use server-returned capabilities and safe denial reasons to shape navigation,
fields and actions. The same authority must govern direct writes, search,
exports and relationship options. UI visibility is presentation, not an
authorization boundary. As capability requests load, represent pending/error
states rather than briefly exposing allowed controls.

## 5. Make automatic behavior inspectable

**Source finding.** Ash supports descriptive policy checks and policy breakdown
logging, and exposes action pipeline metadata for introspection.
[Ash policies](https://ash.hexdocs.pm/policies.html),
[Ash action introspection](https://ash.hexdocs.pm/actions.html#introspection).

**Beak proposal.** Add an explain inspector and CLI checks around the compiled
configuration. For a field, show its resolved editor, default, validation,
dependencies, permissions, data source and save behavior, with source locations.
For Save, show the proposed record/relationship operations and explain why it is
disabled. Include pending remote checks, invalid hidden fields and unsupported
adapter capabilities. Redact secrets and unauthorized values.

Generator diagnostics should reject mismatched fragments, dependency cycles,
unsafe action inputs and requested features unsupported by the selected
transport before an administrator encounters them. Provide a test harness that
drives the same compiled definition through create, edit, cancellation,
relationship changes and direct API rejection.

## Suggested sequence and proof

1. Compile shared action, dependency and reusable presentation metadata; avoid
   expanding isolated field options before establishing these contracts.
2. Implement one vertical shop flow: changing customer resets an invalid profile;
   choosing a product suggests its price until overridden; totals preview from
   the draft; issuing the invoice validates and snapshots values on the server.
3. Prove all consumers agree: the action works from a wizard, table and direct
   API; concurrent changes produce a conflict; other open views refresh;
   cancelling leaves owned drafts and staged files uncommitted.
4. Add the inspector alongside those primitives, then build bulk actions,
   resumable drafts and dashboards from the same contracts.

The success measure is application glue removed and behavior made predictable,
not the number of configuration methods. Some business semantics still require
an explicit choice: tax policy, when an invoice becomes immutable, what a
relationship deletion means, and whether an external operation is retryable.
Beak should ask for that choice once and execute it consistently everywhere.
