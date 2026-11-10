import 'definition_model.dart';
import 'generate_issue.dart';
import 'definition_set.dart';

/// The command input a `@CommandInput` class declares.
DefinitionInput inputOf(DefinitionClass definition, BeakIssueSink issues) {
  final fields = <String, DefinitionInputField>{};
  for (final field in definition.fields) {
    final relation = field.relation;
    if (relation != null) {
      if (relation.kind != DefinitionRelationKind.belongsTo) {
        issues.add(
          definition.path,
          '${definition.name}.${field.name}: a command input only belongs to '
          'models.',
        );
        continue;
      }
      fields[field.name] = DefinitionInputField(
        belongsTo: relation.target,
        foreignKey: '${field.name}Id',
        required: !field.nullable,
        label: field.label ?? relation.label,
      );
      continue;
    }
    if (!const {
      'String',
      'int',
      'double',
      'bool',
      'DateTime',
    }.contains(field.typeName)) {
      issues.add(
        definition.path,
        '${definition.name}.${field.name} is a ${field.typeName}; an input '
        'field is a String, int, double, bool or DateTime.',
      );
      continue;
    }
    fields[field.name] = DefinitionInputField(
      type: field.typeName,
      required: !field.nullable,
      label: field.label,
    );
  }
  return DefinitionInput(
    name: definition.name,
    path: definition.path,
    library: definition.library,
    fields: fields,
    table: definition.inputTable,
  );
}
