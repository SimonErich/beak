import '../schema/beak_schema_ir.dart';
import '../schema/beak_schema_reader.dart' show titleCaseOf;
import '../introspect/beak_schema_introspection.dart' show isSecretColumnName;
import 'database_definition.dart';
import 'generate_issue.dart';
import 'generate_settings.dart';
import 'definition_set.dart';
import 'spy_model.dart';

part 'serverpod_ir_checks.dart';
part 'serverpod_ir_draft.dart';
part 'serverpod_ir_columns.dart';
part 'serverpod_ir_kinds.dart';
part 'serverpod_ir_relations.dart';
part 'serverpod_ir_admission.dart';
part 'serverpod_ir_inputs.dart';
part 'serverpod_ir_helpers.dart';

/// Everything `beak generate` derives from the Serverpod project.
final class ServerpodIr {
  /// Creates a generated project.
  const ServerpodIr({
    required this.models,
    required this.inputs,
    required this.enums,
    required this.writes,
  });

  /// The exposed models, in definition order.
  final List<BeakGeneratedModel> models;

  /// The non-persisted command inputs.
  final List<BeakGeneratedInput> inputs;

  /// The Serverpod enums the models use.
  final List<BeakGeneratedEnum> enums;

  /// The write bindings, one per writable model, emitted as an enum.
  final List<String> writes;
}

/// Reads the Serverpod models, the newest migration and the definition
/// classes (as an [DefinitionSet]) into the IR the emitter writes.
///
/// [prefix] names the write enum (`<prefix>Write`).
ServerpodIr buildServerpodIr({
  required SpyProject project,
  required DatabaseDefinition database,
  required DefinitionSet definitions,
  required BeakGenerateSettings settings,
  required String prefix,
}) {
  final issues = BeakIssueSink();
  _validateRoleNames(project, settings, issues);
  final schemas = <String, BeakSchemaIr>{};
  final drafts = <String, _Draft>{};
  for (final resource in definitions.resources.values) {
    final spy = project.classes[resource.name];
    final table = spy?.table;
    if (spy == null || table == null) {
      issues.add(resource.path, '${resource.name} is not a persisted model.');
      continue;
    }
    if (spy.serverOnly) {
      issues.add(resource.path, '${resource.name} is serverOnly.');
      continue;
    }
    if (database.tables[table] == null) {
      issues.add(
        resource.path,
        '${resource.name} maps to "$table", which the newest migration does '
        'not contain. Run `serverpod create-migration` first.',
      );
      continue;
    }
    drafts[resource.name] = _draftFor(
      project,
      database.tables[table]!,
      spy,
      resource,
      settings,
      issues,
    );
  }
  for (final entry in drafts.entries) {
    schemas[entry.key] = entry.value.schema;
  }
  final byTable = {
    for (final entry in drafts.entries)
      project.classes[entry.key]!.table!: entry.key,
  };
  final usedEnums = <String>{if (settings.roles case final String role) role};
  for (final entry in drafts.entries) {
    _addRelations(
      project,
      database,
      entry.value,
      schemas,
      byTable,
      definitions.resources[entry.key]!,
      usedEnums,
      issues,
    );
  }
  // Admission comes after every relation, so a child already carries the
  // shadow foreign key a one-sided parent added to it.
  final models = <BeakGeneratedModel>[];
  for (final entry in drafts.entries) {
    final resource = definitions.resources[entry.key]!;
    final draft = entry.value;
    _checkRelationKinds(draft, resource, issues);
    final admission = _admissionFor(draft, resource, prefix, issues);
    final permissions = _permissionsFor(resource, settings);
    final capabilities = {
      for (final operation in resource.operations) operation,
    };
    models.add(
      BeakGeneratedModel(
        schema: draft.schema,
        capabilities: capabilities,
        permissions: permissions,
        admission: admission,
      ),
    );
  }
  _validateDefinitionSet(project, database, definitions, drafts, issues);
  final inputs = _inputs(project, definitions, schemas, usedEnums, issues);
  issues.throwIfAny();
  final enums = <String, BeakGeneratedEnum>{
    for (final model in models)
      for (final column in model.schema.columns)
        if (column.enumTypeName case final String name)
          if (project.enums[name] case final SpyEnum type) name: _enumOf(type),
    for (final name in usedEnums)
      if (project.enums[name] case final SpyEnum type) name: _enumOf(type),
  };
  return ServerpodIr(
    models: models,
    inputs: inputs,
    enums: enums.values.toList()..sort((a, b) => a.name.compareTo(b.name)),
    writes: [
      for (final resource in definitions.resources.values)
        if (resource.write case final String write) write,
    ],
  );
}
