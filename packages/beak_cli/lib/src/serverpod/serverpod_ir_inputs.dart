part of 'serverpod_ir.dart';

List<BeakGeneratedInput> _inputs(
  SpyProject project,
  DefinitionSet definitions,
  Map<String, BeakSchemaIr> schemas,
  Set<String> usedEnums,
  BeakIssueSink issues,
) {
  final inputs = <BeakGeneratedInput>[];
  for (final input in definitions.inputs.values) {
    final columns = <BeakColumnIr>[
      const BeakColumnIr(
        fieldName: 'id',
        columnKey: 'id',
        label: 'Id',
        kind: BeakColumnKind.string,
        isRequired: false,
        arguments: {'visibleOn': '{}'},
      ),
    ];
    final relations = <BeakRelationIr>[];
    for (final entry in input.fields.entries) {
      final name = entry.key;
      final field = entry.value;
      final belongsTo = field.belongsTo;
      if (belongsTo != null) {
        final target = schemas[belongsTo];
        if (target == null) {
          issues.add(
            input.path,
            '${input.name}.$name belongs to "$belongsTo", which is not '
            'admitted.',
          );
          continue;
        }
        final fk = field.foreignKey ?? '${name}Id';
        final idColumn = target.columns
            .where((column) => column.fieldName == 'id')
            .firstOrNull;
        columns.add(
          BeakColumnIr(
            fieldName: fk,
            columnKey: fk,
            label: titleCaseOf(fk),
            kind: idColumn?.kind ?? BeakColumnKind.string,
            isRequired: field.required,
            arguments: {
              if (idColumn?.arguments['semantic'] case final String semantic)
                'semantic': semantic,
            },
          ),
        );
        relations.add(
          BeakRelationIr(
            fieldName: name,
            key: name,
            label: field.label ?? titleCaseOf(name),
            kind: BeakRelationKind.belongsTo,
            relatedSchema: belongsTo,
            foreignKey: fk,
            isRequired: field.required,
          ),
        );
        continue;
      }
      final type = field.type ?? 'String';
      final kind = switch (type) {
        'int' => BeakColumnKind.integer,
        'double' => BeakColumnKind.decimal,
        'bool' => BeakColumnKind.boolean,
        'DateTime' => BeakColumnKind.dateTime,
        _ => BeakColumnKind.string,
      };
      columns.add(
        BeakColumnIr(
          fieldName: name,
          columnKey: name,
          label: field.label ?? titleCaseOf(name),
          kind: kind,
          isRequired: field.required,
        ),
      );
    }
    final schema = BeakSchemaIr(
      className: input.name,
      table: input.table ?? 'input_${_snake(input.name)}',
      libraryPath: input.library,
      columns: columns,
      relations: relations,
      displayColumnKey: columns.isEmpty ? 'id' : columns.first.fieldName,
      softDeletes: false,
      timestamps: false,
      managesSchema: false,
      hasBehavior: true,
      hasPermissions: true,
      hasCapabilities: true,
    );
    inputs.add(BeakGeneratedInput(schema));
  }
  return inputs;
}
