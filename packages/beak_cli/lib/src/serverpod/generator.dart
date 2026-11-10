import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../cli_runner.dart';
import '../labels/project_label_loader.dart';
import '../project/beak_project_config.dart';
import '../schema/beak_schema_emitter.dart';
import '../version.dart';
import 'database_definition.dart';
import 'definition_inventory.dart';
import 'definition_libraries.dart';
import 'definition_reader.dart';
import 'generate_issue.dart';
import 'generate_sync.dart';
import 'handler_emitter.dart';
import 'serverpod_ir.dart';
import 'spy_reader.dart';

export 'generate_sync.dart' show beakGeneratedHeader;

/// What one `beak generate` run did.
final class BeakGenerateResult {
  /// Creates a result.
  const BeakGenerateResult({
    this.written = const [],
    this.unchanged = const [],
    this.removed = const [],
    this.problems = const [],
    this.warnings = const [],
  });

  /// Generated files whose contents changed.
  final List<String> written;

  /// Generated files already up to date.
  final List<String> unchanged;

  /// Generated files nothing produces any more.
  final List<String> removed;

  /// Why `--check` failed, or an empty list when the output is current.
  final List<String> problems;

  /// What is worth fixing but does not fail the run, such as a shown field
  /// without a label in some language.
  final List<String> warnings;

  /// Whether the output is current (a check) or was made current (a run).
  bool get isSuccess => problems.isEmpty;

  /// The process exit code.
  int get exitCode => isSuccess ? 0 : 1;
}

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
  final inventory = inventoryOf(
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
    inventory: inventory,
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
  final handlers = settings.handlers;
  final byName = {
    for (final definition in classes) definition.name: definition,
  };
  if (handlers == null) {
    for (final definition in classes) {
      if (definition.needsHandler) {
        issues.add(
          definition.path,
          '${definition.name} runs custom code on the server, so beak.yaml '
          'needs generate.handlers: the folder in the Serverpod server the '
          'handler base classes go into.',
        );
      }
    }
    issues.throwIfAny();
  } else {
    final folder = p.normalize(p.join(root.path, handlers));
    final emitted = emitServerpodHandlers(
      prefix: prefix,
      imports: HandlerImports(
        definitions: definitionsPackage,
        server: _packageName(File(p.join(serverRoot.path, 'pubspec.yaml'))),
        folder: p.isWithin(p.join(serverRoot.path, 'lib'), folder)
            ? p.posix.joinAll(
                p.split(
                  p.relative(folder, from: p.join(serverRoot.path, 'lib')),
                ),
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
    areas.add(GeneratedArea(Directory(folder)));
  }
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

String _partPathOf(String library) =>
    '${library.substring(0, library.length - '.dart'.length)}.beak.dart';

String _packageName(File pubspec) {
  final Object? yaml = loadYaml(pubspec.readAsStringSync());
  if (yaml is YamlMap && yaml['name'] is String) {
    return yaml['name'] as String;
  }
  throw BeakGenerateException.single(
    pubspec.path,
    'pubspec.yaml needs a package `name:`.',
  );
}

String _prefixOf(String packageName) {
  final base = packageName.endsWith('_definitions')
      ? packageName.substring(0, packageName.length - '_definitions'.length)
      : packageName;
  final parts = base.split(RegExp('[_-]'));
  return parts
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join();
}

String _stampContent({
  required Directory root,
  required File configFile,
  required Directory serverRoot,
  required Directory definitions,
  required List<File> labelFiles,
  required String package,
}) {
  final generated = p.join(definitions.path, 'src', 'generated');
  final inputs = <String>[];
  for (final file in [
    configFile,
    for (final entity in serverRoot.listSync(recursive: true))
      if (entity is File &&
          (entity.path.endsWith('.spy.yaml') ||
              entity.path.endsWith('definition_project.json')))
        entity,
    for (final entity in definitions.listSync(recursive: true))
      if (entity is File &&
          entity.path.endsWith('.dart') &&
          !entity.path.endsWith('.beak.dart') &&
          !p.isWithin(generated, entity.path))
        entity,
    ...labelFiles,
  ]..sort((a, b) => a.path.compareTo(b.path))) {
    final path = p.relative(file.path, from: root.path);
    inputs.add(
      '${sha256.convert(utf8.encode(path)).toString()}:'
      '${sha256.convert(file.readAsBytesSync()).toString()}',
    );
  }
  final stamp = {
    'tool': 'beak generate',
    'beak': beakCliVersion,
    'package': package,
    'inputs': sha256.convert(utf8.encode(inputs.join('\n'))).toString(),
  };
  return '${const JsonEncoder.withIndent('  ').convert(stamp)}\n';
}

/// Whether the project at [root] configures `beak generate`.
bool hasServerpodGenerate(Directory root) {
  final file = File(p.join(root.path, 'beak.yaml'));
  if (!file.existsSync()) return false;
  try {
    final Object? yaml = loadYaml(file.readAsStringSync());
    return yaml is YamlMap &&
        yaml['serverpod'] is YamlMap &&
        yaml['generate'] is YamlMap;
  } on Object {
    // `beak prepare` reports a malformed config itself.
    return false;
  }
}
