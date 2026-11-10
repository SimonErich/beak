import '../schema/beak_schema_ir.dart';
import 'definition_model.dart';

/// Writes the abstract `<Model>Handler`: one method per custom operation,
/// `derive` for a derived one, one per command, and the generated `writes`
/// that routes Beak's save operations to them.
void writeHandlerBase(
  StringBuffer buffer,
  BeakGeneratedModel model,
  DefinitionClass definition,
) {
  final name = definition.name;
  final write = '${name}Write';
  final derived = [
    if (definition.create == DefinitionHandling.derived) 'create',
    if (definition.update == DefinitionHandling.derived) 'update',
  ];
  buffer
    ..writeln('/// The server side of the $name admin model.')
    ..writeln('///')
    ..writeln(
      '/// Each abstract method is an operation the definition opens as '
      'custom.',
    )
    ..writeln(
      '/// Beak has checked permissions, admission and rules before it runs, '
      'and',
    )
    ..writeln(
      "/// it runs in the request's transaction: pass `write.transaction` on.",
    )
    ..writeln('abstract base class ${name}Handler {')
    ..writeln('  /// Creates the handler.')
    ..writeln('  const ${name}Handler();')
    ..writeln();
  if (definition.list == DefinitionHandling.custom) {
    buffer
      ..writeln(
        '  /// The rows of $name [principal] reaches in a list, a count, an',
      )
      ..writeln('  /// export and when opening one, or `null` for every row.')
      ..writeln('  BeakFilter? scope(BeakPrincipal principal);')
      ..writeln();
  }
  if (definition.create == DefinitionHandling.custom) {
    buffer
      ..writeln('  /// Saves a new $name; returns the id of the saved record.')
      ..writeln('  Future<Object?> create($write write);')
      ..writeln();
  }
  if (definition.update == DefinitionHandling.custom) {
    buffer
      ..writeln('  /// Saves a change to a $name; returns its id.')
      ..writeln('  Future<Object?> update($write write);')
      ..writeln();
  }
  if (definition.delete == DefinitionHandling.custom) {
    buffer
      ..writeln('  /// Deletes a $name.')
      ..writeln('  Future<void> delete($write write);')
      ..writeln();
  }
  if (derived.isNotEmpty) {
    buffer
      ..writeln(
        '  /// Trusted values laid over '
        '${derived.map((kind) => kind == 'create' ? 'a create' : 'an update').join(' or ')}'
        ' before it is saved,',
      )
      ..writeln('  /// or `null` for none.')
      ..writeln('  FutureOr<BeakRecord?> derive($write write);')
      ..writeln();
  }
  for (final command in definition.commands) {
    buffer
      ..writeln(
        '  /// Runs the `$command` command; returns the id of the record',
      )
      ..writeln('  /// it changed, or `null`.')
      ..writeln('  Future<Object?> $command($write write);')
      ..writeln();
  }
  final stockFallback =
      [definition.create, definition.update, definition.delete].any(
        (op) =>
            op == DefinitionHandling.stock || op == DefinitionHandling.derived,
      );
  final modelSource = 'const admin.${model.schema.modelClass}()';
  buffer
    ..writeln('  /// How Beak runs the writes of $name; generated from the')
    ..writeln('  /// definition.')
    ..writeln('  BeakWriteHandler get writes => BeakWriteHandler.commands(');
  if (definition.commands.isNotEmpty) {
    buffer.writeln('    actions: beakServerpodCommands($modelSource, {');
    for (final command in definition.commands) {
      buffer.writeln(
        "      '$command': (context) => $command($write.of(context)),",
      );
    }
    buffer.writeln('    }),');
  }
  if (definition.create == DefinitionHandling.custom) {
    buffer.writeln('    create: (context) => create($write.of(context)),');
  }
  if (definition.update == DefinitionHandling.custom) {
    buffer.writeln('    update: (context) => update($write.of(context)),');
  } else if (!definition.update.isOpen && definition.commands.isNotEmpty) {
    buffer.writeln('    update: beakServerpodRefused,');
  }
  if (definition.delete == DefinitionHandling.custom) {
    buffer
      ..writeln('    delete: (context) async {')
      ..writeln('      await delete($write.of(context));')
      ..writeln('      return null;')
      ..writeln('    },');
  }
  if (derived.length == 2) {
    buffer.writeln('    derive: (context) => derive($write.of(context)),');
  } else if (derived.length == 1) {
    buffer
      ..writeln('    derive: (context) =>')
      ..writeln(
        '        context.operation.kind == BeakSaveOperationKind.${derived.single}',
      )
      ..writeln('        ? derive($write.of(context))')
      ..writeln('        : null,');
  }
  buffer
    ..writeln(
      '    otherwise: BeakUnmatched.${stockFallback ? 'stock' : 'refuse'},',
    )
    ..writeln('  );')
    ..writeln('}');
}
