part of 'generator.dart';

/// Adds the generated handler classes and their folder to [files].
GeneratedArea? _emitHandlers({
  required String definitionsPackage,
  required List<DefinitionClass> classes,
  required ServerpodIr ir,
  required Map<String, String> files,
  required Directory root,
  required Directory serverRoot,
  required BeakGenerateSettings settings,
  required String prefix,
}) {
  final handlers = settings.handlers;
  final byName = {
    for (final definition in classes) definition.name: definition,
  };
  if (handlers == null) {
    for (final definition in classes) {
      if (definition.needsHandler) {
        throw BeakGenerateException.single(
          definition.path,
          '${definition.name} runs custom code on the server, so beak.yaml '
          'needs generate.handlers: the folder in the Serverpod server the '
          'handler base classes go into.',
        );
      }
    }
    return null;
  }
  final folder = p.normalize(p.join(root.path, handlers));
  final emitted = emitServerpodHandlers(
    prefix: prefix,
    imports: HandlerImports(
      definitions: definitionsPackage,
      server: _packageName(File(p.join(serverRoot.path, 'pubspec.yaml'))),
      folder: p.isWithin(p.join(serverRoot.path, 'lib'), folder)
          ? p.posix.joinAll(
              p.split(p.relative(folder, from: p.join(serverRoot.path, 'lib'))),
            )
          : null,
    ),
    models: [
      for (final model in ir.models) (model, byName[model.schema.className]!),
    ],
  );
  for (final entry in emitted.entries) {
    files[p.join(folder, entry.key)] = entry.value;
  }
  return GeneratedArea(Directory(folder));
}
