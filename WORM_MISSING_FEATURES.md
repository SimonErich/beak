# WORM — features needed by the superdashboard build

Design record for the generic worm capabilities the `beak_superdashboard`
demo needs. Each entry states why it belongs in worm (generic — useful to any
worm consumer, nothing Beak-specific), its status, and a full implementation
brief so it can be (re)built or reviewed in isolation.

Scope rule applied throughout: worm stays framework-agnostic. Anything
Beak-flavored lives in `beak_*` packages; anything demo-specific lives in
`apps/beak_superdashboard`.

---

## 1. Richer seedable `FakerService` — ✅ IMPLEMENTED

**File:** `packages/worm/lib/src/factory/faker_service.dart`
**Tests:** `packages/worm/test/src/factory/faker_service_test.dart`

**Why worm:** every worm consumer that seeds volume data needs reproducible
fake values; the service already existed but covered only names, emails, and
phone numbers over 16-entry datasets.

**Brief / what was added** (all deterministic under `seed(int)`, drawing from
one internal `Random` so sequences reproduce exactly):

- Value generators: `intBetween(min, max)` (inclusive),
  `decimalBetween(min, max, {fractionDigits})`, `dateBetween(start, end)`,
  `boolean({probability})`, `element(List<T>)`,
  `weighted(Map<T, int>)` (zero-weight keys never drawn; insertion order
  keeps draws deterministic), `hexColor()`.
- Content generators: `word()`, `sentence({wordCount})`,
  `paragraph({sentenceCount})`, `company()`, `jobTitle()`, `city()`,
  `country()` → `FakerCountry {name, isoCode}` (paired ISO 3166-1 alpha-2),
  `imageUrl({width, height})`, `avatarUrl()` (placeholder-service URLs).
- **Deterministic id minter:** `uuid()` — RFC-4122 v4-shaped ids minted from
  the seeded stream. Same seed → same id sequence, so volume rows and
  cross-domain foreign keys stay stable across seed runs without hand-rolled
  counters.
- `Random get random` — the seeded stream itself, exposed so callers can
  compose their own values on the same reproducible sequence.
- `email()` uniqueness ledger: the 16×16 bundled name sets collide after
  ~256 draws; a numeric suffix now guarantees uniqueness (needed for
  `unique(['email'])` columns). `seed()` resets the ledger so runs stay
  reproducible.

Datasets stay deliberately small and stable (reproducibility across upstream
`faker_dart` releases). Errors are typed `ArgumentError`s on inverted ranges,
empty lists, and non-positive weight tables.

---

## 2. Self-referential eager loading — status: verified in Phase 3

**Where:** worm eager loader + `beak_backend` `WormDataSource`.

**Why worm:** trees are ordinary relational shapes (folders, comment replies,
org charts). A has-many/belongs-to whose `relatedTable` equals the owning
table must eager-load like any other relation.

**Brief:** verify (and fix if broken) that a relation pointing at its own
table — `file_folders.children` via `parent_id`, `activities.replies` via
`parent_id` — loads correctly through `withRelations` and the Beak data
source, with no infinite recursion and correct row→parent grouping when
parent and child rows share the table. Note: commit `676cfea` already guards
the depth-3 shared-head eager-load merge; the self-reference case needs its
own regression test at the `WormDataSource` layer. See Phase 3 notes below
once executed.

---

## 3. Backlog — documented, intentionally not implemented now

These were evaluated for the superdashboard build and worked around; they
remain worthwhile generic worm improvements.

### 3a. Composite primary keys in the schema builder
`BlueprintTable` exposes only per-column `primary()`. Pivot tables therefore
declare `unique([a, b])` plus implicit rowid (the pattern the reference app
established). A `table.primary(['a', 'b'])` would express pivot identity
directly. Workaround is fully functional, so deferred.

### 3b. Default expressions + enum-default bridge
`withDefault(...)` renders literals only — no `now()` /
`gen_random_uuid()` expressions, and `timestamps()` emits nullable columns
without DB defaults. Separately, an enum column's model-level default is
re-typed by hand in each migration (`.withDefault('draft')`). Bridging
model-declared defaults into schema defaults would remove one drift surface.
Migrations author defaults explicitly today, so deferred.

### 3c. Pivot tables carrying data
Relationship configs model pivots as two foreign keys only. Pivots that
carry columns (role, unread_count, last_read_at on a conversation↔user
pivot) can't be expressed as a relationship. **Decision:** model such pivots
as first-class models/tables (`conversation_participants`) — cleaner than
extending the relationship config, and needs no worm change. Recorded here
so the pattern is deliberate, not an omission.

### 3d. Registry-driven seeding / schema-parity tooling
Seeding via `InsertDescriptor` is stringly-typed relative to the model
layer's typed columns; nothing asserts model ⟷ migration ⟷ seed agreement.
The superdashboard app closes this gap app-side with a schema-parity test
(every model column has a migration column and vice versa). A generic
worm-level assertion helper would generalize it, but it needs a model
metadata source — in Beak's case the `BeakModelRegistry`, which is a Beak
concept, so a worm-generic version must stay registry-agnostic. Deferred.
