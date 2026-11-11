import 'database_definition.dart';
import 'definition_area.dart';
import 'definition_checks.dart';
import 'definition_inputs.dart';
import 'definition_model.dart';
import 'generate_issue.dart';
import 'generate_settings.dart';
import 'definition_set.dart';
import 'spy_model.dart';

/// Fields Serverpod or Beak own on every model.
const Set<String> serverOwnedFields = {
  'id',
  'createdAt',
  'updatedAt',
  'deletedAt',
  'isDeleted',
};

/// Turns the definition classes into the checked definitions the IR uses,
/// checking each declared field against the Serverpod model.
DefinitionSet definitionSetOf(
  List<DefinitionClass> classes,
  SpyProject project,
  DatabaseDefinition database,
  BeakGenerateSettings settings,
  BeakIssueSink issues,
) {
  final resources = <String, DefinitionResource>{};
  final inputs = <String, DefinitionInput>{};
  final names = {for (final definition in classes) definition.name};
  for (final definition in classes) {
    if (resources.containsKey(definition.name) ||
        inputs.containsKey(definition.name)) {
      issues.add(definition.path, '${definition.name} is declared twice.');
      continue;
    }
    if (definition.input) {
      inputs[definition.name] = inputOf(definition, issues);
      continue;
    }
    final spy = project.classes[definition.name];
    if (spy == null) {
      issues.add(
        definition.path,
        '${definition.name} is not a Serverpod model. A definition class has '
        'the name of the .spy.yaml class it exposes.',
      );
      continue;
    }
    final resource = _resource(
      definition,
      spy,
      project,
      database,
      settings,
      names,
      {
        for (final other in classes)
          if (!other.input) other.name: other,
      },
      issues,
    );
    if (resource != null) resources[definition.name] = resource;
  }
  for (final definition in classes) {
    for (final input in definition.commandInputs.values) {
      if (!inputs.containsKey(input)) {
        issues.add(
          definition.path,
          '${definition.name} names $input as a command input, but no '
          '@CommandInput class has that name.',
        );
      }
    }
  }
  return DefinitionSet(resources: resources, inputs: inputs);
}

DefinitionResource? _resource(
  DefinitionClass definition,
  SpyClass spy,
  SpyProject project,
  DatabaseDefinition database,
  BeakGenerateSettings settings,
  Set<String> names,
  Map<String, DefinitionClass> byName,
  BeakIssueSink issues,
) {
  final path = definition.path;
  final name = definition.name;
  final table = database.tables[spy.table];
  final spyFields = {
    for (final field in project.fieldsOf(spy)) field.name: field,
  };
  final declared = {for (final field in definition.fields) field.name: field};
  final exclude = <String>[];
  final scalarRelations = <String>[];
  // Keys, timestamps and soft delete are Serverpod's: always exposed, so a
  // class never loses them by leaving them out.
  final implied = <String>{...serverOwnedFields};
  for (final field in spyFields.values) {
    final relation = field.relation;
    if (relation == null || field.isCollection) continue;
    final relationName = relationNameOf(field);
    final key = foreignKeyOf(field);
    if (declared[relationName]?.relation != null) {
      implied.add(key);
    } else if (declared.containsKey(key)) {
      scalarRelations.add(field.name);
    }
  }
  for (final field in spyFields.values) {
    if (serverOwnedFields.contains(field.name)) continue;
    final relation = field.relation;
    final isDeclared = relation != null && !field.isCollection
        ? declared[relationNameOf(field)]?.relation != null ||
              scalarRelations.contains(field.name)
        : declared.containsKey(field.name) || implied.contains(field.name);
    if (!isDeclared) exclude.add(field.name);
  }
  checkDeclaredFields(definition, spyFields, table, project, names, issues);
  final writeFields = <String>[];
  for (final field in definition.fields) {
    if (field.readOnly || field.hidden) continue;
    if (serverOwnedFields.contains(field.name)) continue;
    final relation = field.relation;
    if (relation == null) {
      writeFields.add(field.name);
      continue;
    }
    if (relation.kind != DefinitionRelationKind.belongsTo) continue;
    final spyField = spyFields[field.name] ?? spyFields['${field.name}Id'];
    if (spyField != null) writeFields.add(foreignKeyOf(spyField));
  }
  final opensFields = definition.create.isOpen || definition.update.isOpen;
  final operations = [
    'read',
    if (definition.create.isOpen) 'create',
    if (definition.update.isOpen || definition.commands.isNotEmpty) 'update',
    if (definition.delete.isOpen) 'delete',
  ];
  if (definition.create == DefinitionHandling.stock) {
    checkStockCreate(definition, spyFields, writeFields, issues);
  }
  checkDefinitionArea(definition, settings, issues);
  final display = [
    for (final field in definition.fields)
      if (field.display && field.relation == null) field.name,
  ];
  if (display.length > 1) {
    issues.add(path, '$name marks ${display.join(', ')} @Display; keep one.');
  }
  final displayTranslation = _displayTranslationOf(
    definition,
    byName,
    path,
    issues,
  );
  return DefinitionResource(
    name: name,
    path: path,
    library: definition.library,
    area: definition.area,
    operations: operations,
    write: definition.write,
    writeFields: definition.writes
        ? (opensFields ? writeFields : const [])
        : null,
    ownedRelations: [
      for (final field in definition.fields)
        if (field.relation?.owned ?? false) field.name,
    ],
    scalarRelations: scalarRelations,
    display: display.firstOrNull,
    displayTranslation: displayTranslation,
    exclude: exclude,
    hidden: [
      for (final field in definition.fields)
        if (field.hidden) field.name,
    ],
    defaults: {
      for (final field in definition.fields)
        if (field.hidden && field.hiddenDefault != null)
          field.name: field.hiddenDefault,
    },
    access: DefinitionAccess(operations: definition.access),
    reason: definition.reason,
    restoreKey: definition.restoreKey,
    fields: {
      for (final field in definition.fields)
        field.name: DefinitionResourceField(
          label: field.label ?? field.relation?.label,
          arguments: field.columnArguments,
          doc: field.docComment,
          relation: field.relation?.kind.name,
        ),
    },
    labelKey: definition.labelKey,
    hasBehavior: definition.hasBehavior,
    hasValidationRules: definition.hasValidationRules,
    hasPermissions: definition.hasPermissions,
    docComment: definition.docComment,
  );
}

DefinitionTranslationDisplay? _displayTranslationOf(
  DefinitionClass definition,
  Map<String, DefinitionClass> byName,
  String path,
  BeakIssueSink issues,
) {
  final field = definition.fields
      .where((field) => field.display && field.relation != null)
      .firstOrNull;
  if (field == null) return null;
  final target = byName[field.relation!.target];
  final column = target?.fields
      .where((field) => field.display && field.relation == null)
      .firstOrNull;
  final locale = target?.fields
      .where((field) => field.name == 'locale')
      .firstOrNull;
  if (column == null || locale == null) {
    issues.add(
      path,
      '${definition.name}.${field.name} is @Display but '
      '${field.relation!.target} needs a @Display field and a locale field.',
    );
    return null;
  }
  return DefinitionTranslationDisplay(
    relationKey: field.name,
    columnKey: column.name,
    localeKey: locale.name,
  );
}
