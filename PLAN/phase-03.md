# Phase 03 — beak_core: model metadata + relationships

## Objective
Give Beak an ORM-agnostic way to describe a model (its table, columns, relationships,
soft-delete, display column) and a typed relationship system. This metadata is what the
backend consumes and what a future `beak_serverpod` can also supply.

## Prerequisites
- Phase 02 `✅ DONE`.

## Files created (in `packages/beak_core/lib/src/`)
- `model/beak_model.dart`
- `model/beak_model_registry.dart`
- `relations/beak_relationship.dart` (sealed) + `relations/*.dart`
- barrel updates

## Public API to implement (contract)

### Model metadata (ORM-neutral)
```dart
abstract base class BeakModel {
  const BeakModel();
  String get table;                 // physical table/collection name
  String get displayColumnKey;      // which column represents a record in pickers/links
  List<BeakColumn> get columns;
  List<BeakRelationship> get relationships => const [];
  bool get softDeletes => false;
  BeakColumn get primaryKey;        // default: first column with key 'id'; else throw config

  BeakColumn? columnByKey(String key);
  BeakRelationship? relationshipByKey(String key);
}
```
Key rule: `BeakModel` describes metadata only — it does NOT itself run queries. The
backend pairs a `BeakModel` with a `BeakDataSource` (Phase 07). This is the seam that
lets worm now / Serverpod later both satisfy Beak.

### Relationship types
```dart
sealed class BeakRelationship {
  const BeakRelationship({
    required this.key,               // relation name (matches worm relation name)
    required this.label,
    required this.relatedTable,
    required this.displayColumnKey,  // column on the related model to show
    this.searchColumnKeys = const [],
  });
  final String key; final String label; final String relatedTable;
  final String displayColumnKey; final List<String> searchColumnKeys;
  BeakRenderIntent intentFor(BeakContext context);
  BeakRelationCardinality get cardinality;
}
enum BeakRelationCardinality { one, many }
```
Concrete `final class`es (`const` ctors):
- `BeakBelongsTo` (`foreignKey`) — cardinality `one`; table intent `relationLink`, form
  intent single-select.
- `BeakHasMany` (`foreignKey`, `onDelete: BeakOnDelete`) — `many`; table intent count/
  `relationBadges`, form intent relation-manager/repeater.
- `BeakBelongsToMany` (`pivotTable`, `foreignPivotKey`, `relatedPivotKey`, `allowCreate`,
  `maxAllowed?`, `onDelete`) — `many`; table `relationBadges`, form multi-select.
- `BeakHasOne` (`foreignKey`) — `one`.
- Add `enum BeakOnDelete { cascade, ormCascade, restrict, setNull, setDefault, noAction }`
  mapping 1:1 to worm's `OnDelete` (documented mapping).

### Registry
```dart
final class BeakModelRegistry {
  void register(BeakModel model);
  BeakModel? byTable(String table);
  BeakModel byTableOrThrow(String table);      // throws BeakConfigurationException
  List<BeakModel> get all;
}
```
A single registry instance is created by the app and passed to the backend/frontend.

## Tests to write FIRST
- `beak_model_test.dart` — a sample `ProductModel extends BeakModel`; `columnByKey`,
  `relationshipByKey`, `primaryKey` resolution (and the config throw when no `id`).
- Relationship tests — cardinality, `intentFor` per context, `BeakOnDelete` → worm
  mapping table exhaustive.
- `registry_test.dart` — register/lookup/duplicate handling; `byTableOrThrow` throws
  `BeakConfigurationException` for unknown tables.
- Exhaustive `switch` over `BeakRelationship` compiles + tested.

## Implementation notes / constraints
- Still pure Dart. The worm mapping is documented here but performed in `beak_backend`
  (Phase 07/08) — do NOT import worm into `beak_core`.
- `BeakModel` is `abstract base` so users subclass it but it stays const-friendly.

## Definition of Done (gate)
- [ ] analyze 0 · tests green · `beak_core` coverage 100% · format clean.
- [ ] Exhaustive `switch` guards for relationships tested.
- [ ] STATE.md row 03 → `✅ DONE` + SHA.

## Commit
`feat(beak_core): add ORM-agnostic model metadata, relationships and registry`
