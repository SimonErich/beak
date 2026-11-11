part of 'serverpod_ir.dart';

BeakColumnKind _kindOfDb(String dartType) {
  final type = dartType.replaceAll('?', '');
  return switch (type) {
    'int' || 'Duration' || 'BigInt' => BeakColumnKind.integer,
    'double' => BeakColumnKind.decimal,
    'bool' => BeakColumnKind.boolean,
    'DateTime' => BeakColumnKind.dateTime,
    'UuidValue' => BeakColumnKind.string,
    _ => BeakColumnKind.string,
  };
}

String _fkOf(SpyField field) {
  if (field.relation?.field case final String fieldKey) return fieldKey;
  if (field.name.endsWith('Id') ||
      field.baseType == 'UuidValue' ||
      field.baseType == 'int') {
    return field.columnName;
  }
  return '${field.name}Id';
}

bool _isForeignKey(String name) => name.endsWith('Id');

String _displayOf(List<BeakColumnIr> columns) {
  for (final column in columns) {
    if (column.kind == BeakColumnKind.string &&
        column.fieldName != 'id' &&
        !_isForeignKey(column.fieldName)) {
      return column.fieldName;
    }
  }
  return columns.isEmpty ? 'id' : columns.first.fieldName;
}

String _columnKeyOf(List<BeakColumnIr> columns, String field) {
  for (final column in columns) {
    if (column.fieldName == field || column.columnKey == field) {
      return column.columnKey;
    }
  }
  return field;
}

String? _defaultSource(
  SpyField field,
  DefinitionResource resource,
  ({BeakColumnKind kind, String? enumTypeName}) type,
) {
  final reviewed = resource.defaults[field.name];
  if (reviewed != null) return _literal(reviewed);
  final raw = field.defaultValue;
  if (raw == null || raw == 'now' || raw.isEmpty) return null;
  if (type.enumTypeName != null) return '${type.enumTypeName}.$raw';
  if (RegExp(r'^-?\d+(\.\d+)?$').hasMatch(raw) ||
      raw == 'true' ||
      raw == 'false' ||
      raw == 'null' ||
      raw.startsWith("'") ||
      raw.startsWith('"')) {
    return raw;
  }
  return "'${raw.replaceAll("'", r"\'")}'";
}

String _literal(Object? value) => switch (value) {
  final String text =>
    "'${text.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$').replaceAll('\n', r'\n')}'",
  final bool boolean => '$boolean',
  final num number => '$number',
  null => 'null',
  _ => throw BeakGenerateException.single(
    'beak.yaml',
    'Unsupported default value "$value".',
  ),
};

bool _isMoney(String name, BeakMoneyConvention? money) {
  if (money == null) return false;
  return money.fields.any((pattern) => _matches(pattern, name));
}

bool _isDateOnly(String name, BeakGenerateConventions conventions) =>
    conventions.dateOnly.any((pattern) => _matches(pattern, name));

bool _detailOnly(String name, BeakGenerateConventions conventions, bool id) =>
    id ||
    const {'createdAt', 'updatedAt', 'deletedAt', 'isDeleted'}.contains(name) ||
    conventions.detailOnly.any((pattern) => _matches(pattern, name));

bool _matches(String pattern, String name) {
  if (!pattern.contains('*')) return pattern == name;
  final prefix = pattern.substring(0, pattern.indexOf('*'));
  final suffix = pattern.substring(pattern.indexOf('*') + 1);
  return name.startsWith(prefix) && name.endsWith(suffix);
}
