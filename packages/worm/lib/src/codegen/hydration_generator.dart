/// Emits hydration extension methods.
library;

import 'column_descriptor.dart';
import 'model_descriptor.dart';

/// Generates `fromRow` and `toRow` for a model.
///
/// `fromRow` uses pattern matching (no `as` casts) to lift
/// raw row maps into typed Dart values. `toRow` projects the
/// model into a `Map<String, Object?>` suitable for an adapter.
final class HydrationGenerator {
  /// Creates a [HydrationGenerator] for [descriptor].
  const HydrationGenerator(this.descriptor);

  /// The model whose hydration is generated.
  final ModelDescriptor descriptor;

  /// Renders the hydration extension source.
  String generate() {
    final className = descriptor.className;
    final buffer = StringBuffer()
      ..writeln('/// Hydration helpers for $className.')
      ..writeln('extension ${className}Hydration on $className {')
      ..writeln('  /// Hydrates a $className from a raw row map.')
      ..writeln('  static $className fromRow(Map<String, Object?> row) {');

    for (final column in descriptor.columns) {
      buffer.writeln(_renderFromRowField(column));
    }

    buffer
      ..writeln('    return $className(')
      ..writeAll([
        for (final column in descriptor.columns)
          '      ${column.dartName}: ${column.dartName},',
      ], '\n')
      ..writeln()
      ..writeln('    );')
      ..writeln('  }')
      ..writeln()
      ..writeln('  /// Projects this $className into a row map.')
      ..writeln('  Map<String, Object?> toRow() => <String, Object?>{');

    for (final column in descriptor.columns) {
      buffer.writeln("    '${column.dbName}': ${column.dartName},");
    }
    buffer
      ..writeln('  };')
      ..writeln('}');

    return buffer.toString();
  }

  String _renderFromRowField(ColumnDescriptor column) {
    final dart = column.dartName;
    final db = column.dbName;
    final type = column.dartType;
    if (column.isNullable) {
      return [
        "    final $type? $dart = switch (row['$db']) {",
        '      null => null,',
        '      final $type value => value,',
        '      _ => throw FormatException(',
        "        'Expected $type? for ${descriptor.className}.$dart',",
        '      ),',
        '    };',
      ].join('\n');
    }
    return [
      "    final $type $dart = switch (row['$db']) {",
      '      final $type value => value,',
      '      _ => throw FormatException(',
      "        'Expected $type for ${descriptor.className}.$dart',",
      '      ),',
      '    };',
    ].join('\n');
  }
}
