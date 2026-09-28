# beak_core

The pure-Dart core of Beak: typed columns, rules, relationships, the
serializable `BeakQuerySpec` wire contract, the storage abstraction, the
`BeakDataSource` seam, and the raw `BeakClient` escape hatch.

Part of [**Beak**](https://github.com/SimonErich/beak), a low-code,
configuration-driven admin-panel framework for Dart/Flutter. See the
[architecture guide](../../docs/architecture/index.md) for how the packages fit
together.

## What it is

`beak_core` is pure Dart with no ORM, HTTP-server, or Flutter dependency — it
is the shared vocabulary every other Beak package speaks. You declare a
resource as an annotated `BeakSchema`, and the generator creates columns,
`BeakModel` descriptors and typed field references. That definition drives
table, form, detail, validation, filtering and export. The
`BeakQuerySpec` wire contract travels losslessly as JSON between frontend and
backend, while `BeakDataSource` is the source-agnostic seam (including the Worm and Serverpod adapters) and `BeakClient` is the thin typed REST transport underneath.

## Usage

Most applications generate descriptors from schema annotations. The following
is the lower-level equivalent for adapter or framework authors:

```dart
import 'package:beak_core/beak_core.dart';

abstract final class ProductColumns {
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(255)],
  );
  static const price = BeakDecimalColumn(
    key: 'price',
    label: 'Price',
    prefix: '€',
    filterable: true,
    rules: [BeakRequired(), BeakMin(0)],
  );

  static const List<BeakColumn> values = [name, price];
}

final class ProductModel extends BeakModel {
  const ProductModel();

  @override
  String get table => 'products';
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => ProductColumns.values;
}
```

Compose a query with the immutable copy-builders and ship it as JSON:

```dart
final spec = const BeakQuerySpec(table: 'products')
    .withFilter(BeakFieldFilter(
      column: ProductColumns.price,
      operator: BeakOperator.gte,
      value: BeakValue.of(10),
    ))
    .orderBy(ProductColumns.name)
    .paginate(page: 1, perPage: 50);

final decoded = BeakQuerySpec.fromJson(spec.toJson()); // lossless round-trip
```

## Key types

- `BeakColumn` — sealed, `const`, define-once column (leaves: `BeakStringColumn`,
  `BeakDecimalColumn`, `BeakEnumColumn`, `BeakImageColumn`, …).
- `BeakModel` — ORM-agnostic resource metadata: table, columns, relationships.
- `BeakQuerySpec` — the JSON-serializable query wire contract with copy-builders.
- `BeakRelationship` — `BeakBelongsTo`, `BeakHasMany`, `BeakBelongsToMany`, …
- `BeakRule` / `BeakRecordRule` — scalar, conditional, cross-field and collection validation.
- `BeakModelBehavior` / `BeakModelAction` — shared value lifecycle and named actions.
- `BeakCandidateGraph` — typed final-state graph for transactional business preparation.
- `BeakSavePlan` / `BeakSaveResult` — graph mutation and explicit persistence outcomes.
- `BeakSemantic` / `BeakFormatPolicy` — typed codecs, semantic constraints and formatting.
- `BeakDataSource` — the source-agnostic data boundary both sides speak.
- `BeakClient` — the thin typed REST transport / raw escape hatch.
- `BeakStorageDriver` — pluggable file-storage abstraction with upload rules.

## Status

Pre-1.0, part of the Beak monorepo. Consumed by the
[canonical shop](../../examples/clean_beak_config). Contributions welcome — see
[CONTRIBUTING](../../CONTRIBUTING.md) at the repo root.

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](LICENSE).
