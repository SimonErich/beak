---
title: Export to CSV
description: The generated export route, honouring the same filters the view is showing.
---

# Export to CSV

Every resource gets a generated `POST /api/{table}/export` route. From Dart, the
client turns a query spec into a CSV string, so an export honours the same
filters and sorts the table is showing:

```dart title="packages/beak_core/lib/src/client/beak_client.dart"
  /// Exports [spec]'s rows as CSV via `POST /api/{table}/export`.
  Future<String> export(String table, BeakQuerySpec spec) async {
    final response = await _postJson('/api/$table/export', spec.toJson());
    return response.body;
  }
```

Call it with the same spec the current view built:

```dart
final csv = await client.export('products', spec);
```

## Continue reading

- [Search and export](../backend/search-and-export.md)
