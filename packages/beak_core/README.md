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
resource once, as an annotated `BeakSchema` class, and `beak prepare`
generates the rest: the typed columns, the `BeakModel` descriptor and a typed
field reference per property. That one definition drives the table, form,
detail view, validation, filtering and export. The `BeakQuerySpec` wire
contract travels losslessly as JSON between frontend and backend,
`BeakDataSource` is the source-agnostic seam (the Worm and Serverpod adapters
implement it), and `BeakClient` is the thin typed REST transport underneath.

Applications reach it through the `beak` umbrella package:
`package:beak/beak.dart` re-exports this package's barrel, and
`package:beak/schema.dart` its annotations.

## Usage

Declare the resource as a schema class:

```dart
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'product.beak.dart';

@Resource()
final class Product extends BeakSchema {
  /// What the product is called.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(255)])
  late final String name;

  /// Net unit price in euros.
  @Column(prefix: '€', sortable: true, rules: [BeakMin(0)])
  late final double price;

  /// Whether the product can be sold.
  @Column(defaultValue: true)
  late final bool active;
}
```

Run `beak prepare`. It writes `product.beak.dart` next to the schema, with
`ProductModel` and its typed field references (`ProductModel.name`,
`ProductModel.price`, `ProductModel.active`). Queries start from the model, so
no table or column name is ever typed as a string:

```dart
final spec = const ProductModel()
    .query(
      filter: BeakFilter.allOf([
        ProductModel.active.eq(true),
        ProductModel.price.gte(10),
      ]),
    )
    .paginate(page: 1, perPage: 50);

final decoded = BeakQuerySpec.fromJson(spec.toJson()); // lossless round-trip
```

The model answers aggregates the same way, and a field reference reads its
typed value back out of a loaded record:

```dart
final sellable = await source.aggregate(
  const ProductModel().count(filter: ProductModel.active.eq(true)),
);
final page = await source.query(spec);
final String firstName = ProductModel.name.require(page.items.first);
```

An adapter describing tables Beak does not generate can subclass `BeakModel`
by hand; the generated part file is the reference for what to override.

## Key types

- `BeakColumn` — sealed, `const`, define-once column (leaves: `BeakStringColumn`,
  `BeakDecimalColumn`, `BeakEnumColumn`, `BeakImageColumn`, …).
- `BeakModel` — ORM-agnostic resource metadata: table, columns, relationships.
- `BeakFieldRef` — the generated typed field references (`BeakScalarField`,
  `BeakToOneField`, `BeakToManyField`) that build filters and read records.
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
[canonical shop](../../examples/clean_beak_config) and the
[foodio admin panel](../../examples/foodio-adminpanel). Contributions welcome —
see [CONTRIBUTING](../../CONTRIBUTING.md) at the repo root.

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](LICENSE).
