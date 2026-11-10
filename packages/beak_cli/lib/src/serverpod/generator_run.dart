part of 'generator.dart';

/// Runs `beak generate` for the project at [project].
///
/// [check] writes nothing and reports what would change. The project's
/// `beak.yaml` must carry both `serverpod:` and `generate:`.
BeakGenerateResult runServerpodGenerate(
  BeakCliEnvironment environment, {
  String? project,
  bool check = false,
}) {
  final root = project == null
      ? environment.rootDirectory
      : Directory(p.join(environment.rootDirectory.path, project));
  final configFile = File(p.join(root.path, 'beak.yaml'));
  final pubspec = File(p.join(root.path, 'pubspec.yaml'));
  if (!configFile.existsSync()) {
    throw BeakGenerateException.single(
      'beak.yaml',
      'No Beak project at ${root.path}. Run this from the panel package, or '
          'pass --project <path>.',
    );
  }
  // A container build copies the panel's beak.yaml and dictionaries without
  // its pubspec (it would be a stray workspace member); the directory name is
  // the package name then.
  final packageName = pubspec.existsSync()
      ? _packageName(pubspec)
      : p.basename(root.path);
  final config = BeakProjectConfig.parse(
    configFile.readAsStringSync(),
    packageName: packageName,
  );
  final serverpod = config.serverpod;
  final settings = config.generate;
  if (serverpod == null || settings == null) {
    throw BeakGenerateException([
      const BeakGenerateIssue(
        path: 'beak.yaml',
        message: 'Add `serverpod:` and `generate:` to generate the admin.',
      ),
    ]);
  }
  final serverRoot = Directory(
    p.normalize(p.join(root.path, serverpod.server)),
  );
  final definitions = Directory(
    p.normalize(p.join(root.path, settings.definitions)),
  );
  final definitionsPubspec = File(p.join(definitions.path, 'pubspec.yaml'));
  if (!definitionsPubspec.existsSync()) {
    throw BeakGenerateException.single(
      'beak.yaml',
      'generate.definitions names ${definitions.path}, which has no '
          'pubspec.yaml. It is the pure-Dart package of definition classes.',
    );
  }
  final definitionsPackage = _packageName(definitionsPubspec);
  final prefix = settings.prefix ?? _prefixOf(definitionsPackage);
  final projectModel = SpyReader(serverRoot, serverpod).read();
  final database = DatabaseDefinition.read(serverRoot, serverpod.migrations);
  final issues = BeakIssueSink();
  final classes = readDefinitions(definitions, settings.definitions, issues);
  issues.throwIfAny();
  final checked = definitionSetOf(
    classes,
    projectModel,
    database,
    settings,
    issues,
  );
  checkDefinitionLibraries(
    classes,
    definitionsPackage,
    issues,
    enumNames: projectModel.enums.keys.toSet(),
  );
  issues.throwIfAny();
  final ir = buildServerpodIr(
    project: projectModel,
    database: database,
    definitions: checked,
    settings: settings,
    prefix: prefix,
  );
  final labels = loadProjectLabels(
    root: root,
    settings: config.labels,
    schemas: [
      for (final model in ir.models) model.schema,
      for (final input in ir.inputs) input.schema,
    ],
    enumValues: {
      for (final generated in ir.enums)
        generated.name: [for (final value in generated.values) value.name],
    },
  );
  if (labels.errors.isNotEmpty) {
    throw BeakGenerateException([
      for (final issue in labels.errors)
        BeakGenerateIssue(path: issue.path, message: issue.message),
    ]);
  }
  final lib = p.join(definitions.path, 'lib');
  final generated = p.join(lib, 'src', 'generated');
  final files = <String, String>{};
  for (final model in ir.models) {
    files[p.join(
      lib,
      _partPathOf(model.schema.libraryPath),
    )] = BeakSchemaEmitter.emitServerpodPart(
      model,
      ir.models,
      labels: labels.labels,
    );
  }
  for (final input in ir.inputs) {
    files[p.join(
      lib,
      _partPathOf(input.schema.libraryPath),
    )] = BeakSchemaEmitter.emitServerpodInputPart(
      input,
      ir.models,
      labels: labels.labels,
    );
  }
  files[p.join(
    generated,
    'models.dart',
  )] = BeakSchemaEmitter.emitServerpodModels(
    prefix: prefix,
    package: definitionsPackage,
    models: ir.models,
    enums: ir.enums,
    writes: ir.writes,
    inputs: ir.inputs,
  );
  if (ir.enums.isNotEmpty) {
    files[p.join(generated, 'enums.dart')] = BeakSchemaEmitter.emitEnums(
      ir.enums,
    );
  }
  if (ir.writes.isNotEmpty) {
    files[p.join(generated, 'writes.dart')] = BeakSchemaEmitter.emitWrites(
      prefix,
      ir.writes,
    );
  }
  if (ir.enums.isNotEmpty || ir.writes.isNotEmpty) {
    files[p.join(
      generated,
      'definitions_support.dart',
    )] = BeakSchemaEmitter.emitDefinitionSupport(
      enums: ir.enums.isNotEmpty,
      writes: ir.writes.isNotEmpty,
    );
  }
  final areas = [
    GeneratedArea(Directory(lib), partsOnly: true),
    GeneratedArea(Directory(generated)),
  ];
  final handlerArea = _emitHandlers(
    definitionsPackage: definitionsPackage,
    classes: classes,
    ir: ir,
    files: files,
    root: root,
    serverRoot: serverRoot,
    settings: settings,
    prefix: prefix,
  );
  if (handlerArea != null) areas.add(handlerArea);
  files[p.join(generated, '.beak_generate_stamp.json')] = _stampContent(
    root: root,
    configFile: configFile,
    serverRoot: serverRoot,
    definitions: Directory(lib),
    labelFiles: projectLabelFiles(root, config.labels),
    package: definitionsPackage,
  );
  final result = syncGeneratedFiles(files, areas, check: check);
  return BeakGenerateResult(
    written: result.written,
    unchanged: result.unchanged,
    removed: result.removed,
    problems: result.problems,
    warnings: [for (final issue in labels.warnings) issue.toString()],
  );
}
