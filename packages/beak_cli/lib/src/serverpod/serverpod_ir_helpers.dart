part of 'serverpod_ir.dart';

void _validateDefinitionSet(
  SpyProject project,
  DatabaseDefinition database,
  DefinitionSet definitions,
  Map<String, _Draft> drafts,
  BeakIssueSink issues,
) {
  final tables = <String, String>{};
  for (final draft in drafts.values) {
    final table = draft.spy.table!;
    if (tables.containsKey(table)) {
      issues.add(
        draft.resource.path,
        '${draft.spy.name} and ${tables[table]} both map to "$table".',
      );
    }
    tables[table] = draft.spy.name;
    for (final column in draft.schema.columns) {
      if (!draft.db.columns.containsKey(column.columnKey)) {
        issues.add(
          draft.resource.path,
          '${draft.spy.name}.${column.fieldName} maps to '
          '"${column.columnKey}", which the newest migration lacks.',
        );
      }
    }
  }
}

BeakGeneratedEnum _enumOf(SpyEnum type) => BeakGeneratedEnum(
  name: type.name,
  properties: {
    for (final entry in type.properties.entries) entry.key: entry.value,
  },
  values: [
    for (final value in type.values)
      BeakGeneratedEnumValue(value.name, value.properties),
  ],
);

String _onDeleteOf(String action) => switch (action) {
  'Cascade' => 'cascade',
  'SetNull' => 'setNull',
  'SetDefault' => 'setDefault',
  _ => 'restrict',
};

String _snake(String name) => name
    .replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (match) => '${match[1]}_${match[2]}',
    )
    .toLowerCase();

String _camel(String snake) {
  final parts = snake.split('_');
  return parts.first +
      parts
          .skip(1)
          .map(
            (part) => part.isEmpty
                ? ''
                : '${part[0].toUpperCase()}${part.substring(1)}',
          )
          .join();
}

String _upperFirst(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
