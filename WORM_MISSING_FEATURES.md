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

## 2. Self-referential + scoped eager loading — ✅ IMPLEMENTED

**Files:** `packages/worm/lib/src/relation/relation_base.dart` (+ each
relation type), `packages/worm/lib/src/query/query_context.dart`,
`packages/worm/lib/src/relation/eager_loader.dart`,
`packages/beak_backend/lib/src/data/worm/query_translator.dart`.
**Tests:** `packages/worm/test/src/relation/scoped_relation_resolution_test.dart`,
`packages/beak_backend/test/src/data/worm/self_referential_relations_test.dart`.

**Why worm:** trees are ordinary relational shapes (folders, comment replies,
org charts), and the underlying defect was generic: the eager loader resolved
every nested path segment from the context's ONE flat name→relation map, so
two tables declaring the same relation name with different targets (e.g. two
self-referential `parent` relations) silently loaded rows from whichever
table registered the name first — wrong data, no error.

**What was verified:** plain self-reference (has-many `children` /
belongs-to `parent` on the owning table, nested two levels) already worked —
regression tests now guard it at both the worm and `WormDataSource` layers.

**What was fixed (backwards compatible):**
- `Relation.targetTable` — the loaded side's table when statically known
  (childTable / parentTable / relatedTable; `null` for polymorphic MorphTo).
- `QueryContext.relationsByTable` — optional per-owning-table relation maps.
- `EagerLoader` resolves each path level against the previous segment's
  target table first, falling back to the flat map; an empty
  `relationsByTable` preserves the old behavior exactly.
- `beak_backend`'s translator now hands relations over both ways (scoped
  precedence, flat first-wins fallback), so Beak model graphs with repeated
  relation keys can never cross-wire.

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
