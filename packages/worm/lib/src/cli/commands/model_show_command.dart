/// `worm model:show` command.
library;

import '../cli_context.dart';
import '../worm_command_runner.dart';

/// Prints the registered metadata for one model: table name, field
/// list with types, and relation list. Exits with code `1` when the
/// model is not registered with the [CliContext].
final class ModelShowCommand extends WormCommand {
  /// Creates a [ModelShowCommand].
  ModelShowCommand(super.context);

  @override
  String get name => 'model:show';

  @override
  String get description =>
      'Print the table name, fields, and relations of a registered model.';

  @override
  String get invocation => 'worm model:show <ModelName>';

  @override
  Future<int> run() async {
    final results = argResults;
    if (results == null || results.rest.isEmpty) {
      context.err.writeln('error: model class name is required');
      return 64;
    }
    final modelName = results.rest.first;
    final model = _findModel(modelName);
    if (model == null) {
      context.err.writeln('Model not found: $modelName');
      return 1;
    }
    _printModel(model);
    return 0;
  }

  ModelInfo? _findModel(String name) {
    for (final m in context.models) {
      if (m.name == name) return m;
    }
    return null;
  }

  void _printModel(ModelInfo model) {
    context.out
      ..writeln('Model: ${model.name}')
      ..writeln('Table: ${model.tableName}');
    _printFields(model.fields);
    _printRelations(model.relations);
  }

  void _printFields(List<ModelField> fields) {
    context.out.writeln('Fields:');
    if (fields.isEmpty) {
      context.out.writeln('  (none)');
      return;
    }
    for (final f in fields) {
      context.out.writeln('  ${f.name}: ${f.type}');
    }
  }

  void _printRelations(List<ModelRelation> relations) {
    context.out.writeln('Relations:');
    if (relations.isEmpty) {
      context.out.writeln('  (none)');
      return;
    }
    for (final r in relations) {
      context.out.writeln('  ${r.name}: ${r.kind} ${r.target}');
    }
  }
}
