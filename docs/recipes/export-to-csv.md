---
title: Export to CSV
description: Export the records a list is showing to CSV, honoring the same filters.
type: recipe
audience: [beginner, expert, agent]
status: draft
---

# Export to CSV

For a configured list, `BeakListExport` supplies the download button, active query, typed scalar projection and panel formatting automatically. See [Composed lists](../panel/composed-lists.md) for configuration.

Every resource gets a generated `POST /api/{table}/export` route. From Dart, the
client turns a query spec into a CSV string, so an export honours the same
filters and sorts the table is showing:

```dart title="packages/beak_core/lib/src/client/beak_client.dart"
/// Exports [spec]'s rows as CSV via `POST /api/{table}/export`.
  Future<String> export(
    String table,
    BeakQuerySpec spec, {
    BeakFormatPolicy? formatting,
    List<String>? columns,
    Map<String, BeakExportFormat> formats = const {},
    bool raw = false,
  }) async {
    if (raw && (formatting != null || formats.isNotEmpty)) {
      throw const BeakConfigurationException(
        'Raw exports cannot also request display formatting.',
      );
    }
    final response = await _postJson('/api/$table/export', {
      ...spec.toJson(),
      'columns': ?columns,
      if (formats.isNotEmpty)
        'formats': {
          for (final entry in formats.entries) entry.key: entry.value.toJson(),
        },
      if (formatting != null) 'formatting': formatting.toJson(),
      if (raw) 'raw': true,
    });
    return response.body;
  }
```

Call it with the same spec the current view built:

```dart
final csv = await client.export('products', spec);
```

Use the panel's shared formatting policy for a human-readable report:

```dart
final csv = await client.export(
  'products',
  spec,
  formatting: BeakFormatting.of(context),
);
```

`BeakFormatting` extends the pure-Dart `BeakFormatPolicy`, so the backend uses
the same locale, patterns, currency rules, exact decimal scale, and empty-value
presentation. Serialized policies use UTC unless you explicitly configure a
fixed `timeZoneOffsetMinutes`; they never infer the browser's timezone on the
server. Password fields remain masked.

For physical storage values, use `client.export('products', spec, raw: true)`.
Exact money then exports integer units and durations export integer
microseconds. Without either option, exact money exports canonical major-unit
decimal text and dates/times use canonical representations. Display formatting
and `raw: true` are mutually exclusive.

Low-level `model.sum(column)` and `model.avg(column)` aggregate **storage
units**. For an exact decimal total, use the typed helper:

```dart
final BeakDecimal total = await FulfillmentPolicyModel.deliveryFee.sum(dataSource);
```

This preserves the declared scale and rejects fractional or overflowing integer
results. Averages can contain sub-unit fractions; choose an explicit rounding
policy before converting those results to fixed-scale money.

## Continue reading

- [Search and export](../backend/search-and-export.md)
