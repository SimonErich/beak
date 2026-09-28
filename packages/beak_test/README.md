# beak_test

The testing toolkit for Beak. An app reaches it through
`package:beak/testing.dart`; an adapter author can depend on it directly.

Part of [**Beak**](https://github.com/SimonErich/beak), a low-code,
configuration-driven admin-panel framework for Dart/Flutter.

## What it provides

| Symbol | What it is for |
| --- | --- |
| `InMemoryBeakDataSource` | A complete `BeakDataSource` over maps that honors the whole query spec (filters, sorts, search, paging, relation loads, soft deletes), so a widget test proves something. |
| `BeakRecordingDataSource` | Wraps any source and records every call, for asserting how many round trips a screen costs. |
| `runBeakDataSourceContract` | The executable contract every `BeakDataSource` must pass; a third-party adapter runs it to prove it behaves. |
| `BeakRecordFactory`, `beakFakeRecord` | Fixture records derived from a model's column metadata. |
| `expectSchemaParity`, `expectNoOrphanTables` | Assert that every model has a table with the columns it declares, and the reverse. |

## Usage

```dart
import 'package:beak/testing.dart';

final source = InMemoryBeakDataSource(registry: buildBeakRegistry())
  ..seed(const ProductModel(), [beakFakeRecord(const ProductModel())]);
```

Run `dart test` in this package.
