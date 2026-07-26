# reference_admin_models

The shared model definitions of Beak's reference admin — defined once,
consumed by both the Shelf server and the Flutter panel.

Part of [**Beak**](https://github.com/SimonErich/beak), a low-code,
configuration-driven admin-panel framework for Dart/Flutter. See the
[architecture guide](../../docs/architecture.md) for how the packages fit
together.

## What it is

The "define once" proof of the Beak stack: a pure-Dart library that declares
the demo catalog — Products, Categories, Tags, Users, Orders, Order Items — as
`BeakModel`s built from typed `beak_core` columns and relationships. It depends
only on `beak_core`, imports no server or Flutter code, and is the single
source of truth both `reference_admin_server` (auto CRUD) and `reference_admin`
(resource pages) derive from. The primary entry points are `referenceModels`
and `buildReferenceRegistry`.

## Usage

Each resource is a `*Columns` block of typed constants paired with a `*Model`:

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

`buildReferenceRegistry` bundles every model into the one index Beak consumes:

```dart
import 'package:reference_admin_models/reference_admin_models.dart';

final registry = buildReferenceRegistry();
// registry.byTableOrThrow('products') -> ProductModel
```

## Key types

- `referenceModels` — the canonical `List<BeakModel>`, in registration order.
- `buildReferenceRegistry` — builds the populated `BeakModelRegistry`.
- `ProductModel` / `ProductColumns` — the showcase resource: every column
  kind, upload rules, a transform pipeline, relationships, soft deletes.
- `CategoryModel`, `TagModel`, `UserModel`, `OrderModel`, `OrderItemModel` —
  the remaining catalog resources and their `*Columns`/`*Relations` blocks.

## Status

Pre-1.0, part of the Beak monorepo. This is an example, not a published
package. Consumed by the [reference admin](../../apps/reference_admin) and its
server. Contributions welcome — see [CONTRIBUTING](../../CONTRIBUTING.md) at
the repo root.

## License

Apache-2.0 © Marqably GmbH.
