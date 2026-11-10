import '../schema/beak_reserved_names.dart';
import '../schema/beak_schema_ir.dart';

const String _uuidSemantic = 'BeakSemantic.uuid()';

bool _isUuid(BeakColumnIr column) =>
    column.arguments['semantic'] == _uuidSemantic;

/// Whether the typed values of [schema] read a Serverpod enum.
bool usesProtocol(BeakSchemaIr schema) =>
    schema.columns.any((column) => column.kind == BeakColumnKind.enumeration);

/// Whether the typed values of [schema] read a `UuidValue`.
bool usesUuid(BeakSchemaIr schema) => schema.columns.any(_isUuid);

/// The column's default as source the handler library can use (enum values
/// carry the `admin.` prefix), or `null` for none or a JSON default.
String? _defaultOf(BeakColumnIr column) {
  final source = column.arguments['defaultValue'];
  if (source == null || source == 'null') return null;
  if (column.kind == BeakColumnKind.json) return null;
  if (column.kind == BeakColumnKind.enumeration) return 'admin.$source';
  return source;
}

/// Writes `<Model>Write`: the operation with its values typed.
void writeTypedWrite(StringBuffer buffer, BeakSchemaIr schema) {
  final name = schema.className;
  buffer
    ..writeln('/// A $name write: the operation, and its values typed as')
    ..writeln('/// Serverpod reads them.')
    ..writeln(
      'extension type ${name}Write._(BeakServerpodWrite _write) '
      'implements BeakServerpodWrite {',
    )
    ..writeln('  /// Wraps the operation Beak is saving.')
    ..writeln('  ${name}Write.of(BeakSaveOperationContext context)')
    ..writeln('    : _write = BeakServerpodWrite(context);')
    ..writeln()
    ..writeln('  /// The record after the write: the stored values with the')
    ..writeln('  /// change laid over.')
    ..writeln('  ${name}Values get record => ${name}Values(values);')
    ..writeln()
    ..writeln('  /// The stored record, or `null` for a create.')
    ..writeln('  ${name}Values? get before => switch (existing) {')
    ..writeln('    final BeakRecord stored => ${name}Values(stored),')
    ..writeln('    null => null,')
    ..writeln('  };')
    ..writeln('}')
    ..writeln();
}

/// Writes `<Model>Values`: one getter per column, typed as Serverpod reads
/// it (`UuidValue`, the protocol enum).
void writeTypedValues(StringBuffer buffer, BeakSchemaIr schema) {
  final name = schema.className;
  final model = 'admin.${schema.modelClass}.fields';
  buffer
    ..writeln(
      '/// The fields of a $name record, typed as Serverpod reads them.',
    )
    ..writeln('///')
    ..writeln('/// A required field without a value throws a')
    ..writeln('/// [BeakValidationException] on that field.')
    ..writeln('extension type const ${name}Values(BeakRecord raw) {');
  for (final column in schema.columns) {
    final field = column.fieldName;
    if (field == 'raw' || BeakReservedNames.recordView.contains(field)) {
      continue;
    }
    final required = column.isRequired;
    final fallback = _defaultOf(column);
    final read = !required
        ? '$model.$field.readFrom(raw)'
        : fallback == null
        ? '$model.$field.require(raw)'
        : '$model.$field.readFrom(raw) ?? $fallback';
    buffer
      ..writeln()
      ..writeln('  /// `$field`.');
    if (_isUuid(column)) {
      buffer.writeln(
        required
            ? '  UuidValue get $field => BeakServerpodValues.uuid($read);'
            : '  UuidValue? get $field => '
                  'BeakServerpodValues.uuidOrNull($read);',
      );
      continue;
    }
    if (column.kind == BeakColumnKind.enumeration) {
      final type = 'protocol.${column.enumTypeName}';
      buffer.writeln(
        required
            ? '  $type get $field => '
                  '$type.values.byName(${fallback == null ? read : '($read)'}.name);'
            : '  $type? get $field => switch ($read) {\n'
                  '    final admin.${column.enumTypeName} value => '
                  '$type.values.byName(value.name),\n'
                  '    null => null,\n'
                  '  };',
      );
      continue;
    }
    final type = column.valueType;
    buffer.writeln('  $type${required ? '' : '?'} get $field => $read;');
  }
  buffer
    ..writeln('}')
    ..writeln();
}
