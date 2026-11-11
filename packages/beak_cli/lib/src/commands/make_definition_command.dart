import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../cli_runner.dart';
import '../project/beak_project_config.dart';
import '../serverpod/database_definition.dart';
import '../serverpod/definition_paths.dart';
import '../serverpod/definition_reader.dart';
import '../serverpod/definition_scaffold.dart';
import '../serverpod/generate_issue.dart';
import '../serverpod/generate_settings.dart';
import '../serverpod/spy_model.dart';
import '../serverpod/spy_reader.dart';

/// Writes a new definition class from a Serverpod model.
///
/// The class is a read-only allowlist until its writes are opened: every
/// stored field is declared with Serverpod's type and nullability, relations
/// become `@BelongsTo`, `@HasOne` or `@HasMany`, timestamps and the version
/// are `@ReadOnly`, and Serverpod's `###` docs are copied. The class gets its
/// `part` directive so `beak generate` can write the model beside it.
///
/// ```console
/// $ beak make:definition Book --project apps/shop_admin
///   created apps/shop_admin/definitions/lib/src/catalog/book.dart
/// ```
final class MakeDefinitionCommand extends Command<int> {
  /// Creates the command against [environment].
  MakeDefinitionCommand(this.environment) {
    argParser
      ..addOption(
        'project',
        help: 'The panel package whose beak.yaml configures the run.',
        valueHelp: 'path',
      )
      ..addOption(
        'area',
        help: 'The definition area, when beak.yaml declares more than one.',
        valueHelp: 'name',
      );
  }

  /// The injected seams.
  final BeakCliEnvironment environment;

  @override
  String get name => 'make:definition';

  @override
  String get description =>
      'Write a read-only definition class from a Serverpod model.';

  @override
  String get invocation =>
      'beak make:definition <Model> [--project <path>] [--area <name>]';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1 ||
        !RegExp(r'^[A-Z][A-Za-z0-9]*$').hasMatch(rest.single)) {
      throw UsageException(
        'Expected exactly one UpperCamelCase model name.',
        usage,
      );
    }
    final name = rest.single;
    final root = switch (argResults!['project']) {
      final String path => Directory(
        p.join(environment.rootDirectory.path, path),
      ),
      _ => environment.rootDirectory,
    };
    final configFile = File(p.join(root.path, 'beak.yaml'));
    if (!configFile.existsSync()) {
      environment.out.writeln('error: no beak.yaml in ${root.path}');
      return 1;
    }
    final pubspec = File(p.join(root.path, 'pubspec.yaml'));
    final config = BeakProjectConfig.load(
      root,
      packageName: pubspec.existsSync()
          ? definitionPackageName(pubspec)
          : p.basename(root.path),
    );
    final serverpod = config.serverpod;
    final settings = config.generate;
    if (serverpod == null || settings == null) {
      environment.out.writeln(
        'error: beak.yaml needs serverpod: and generate: to scaffold a '
        'definition.',
      );
      return 1;
    }
    final serverRoot = Directory(
      p.normalize(p.join(root.path, serverpod.server)),
    );
    final project = SpyReader(serverRoot, serverpod).read();
    final spy = project.classes[name];
    if (spy == null) {
      environment.out.writeln('error: $name is not a Serverpod model.');
      return 1;
    }
    final definitions = Directory(
      p.normalize(p.join(root.path, settings.definitions)),
    );
    final definitionsPubspec = File(p.join(definitions.path, 'pubspec.yaml'));
    if (!definitionsPubspec.existsSync()) {
      environment.out.writeln(
        'error: ${definitions.path} has no pubspec.yaml.',
      );
      return 1;
    }
    final area = _areaOf(
      switch (argResults!['area']) {
        final String value => value,
        _ => null,
      },
      spy,
      settings,
    );
    if (area == null) {
      environment.out.writeln(
        'error: ${spy.path} has no area; pass --area <name>. Areas: '
        '${settings.areas.keys.join(', ')}.',
      );
      return 1;
    }
    final issues = BeakIssueSink();
    final existing = readDefinitions(definitions, settings.definitions, issues);
    issues.throwIfAny();
    final database = DatabaseDefinition.read(serverRoot, serverpod.migrations);
    final docs = readSpyDocs(
      File(p.join(serverRoot.path, spy.path)).readAsStringSync(),
    );
    final String source;
    try {
      source = scaffoldDefinition(
        spy,
        project,
        database,
        area: area,
        package: definitionPackageName(definitionsPubspec),
        libraryOf: {
          for (final definition in existing)
            definition.name: definition.library,
        },
        classDoc: docs.classDoc,
        fieldDocs: docs.fields,
      );
    } on DefinitionScaffoldException catch (error) {
      environment.out.writeln('error: ${error.message}');
      return 1;
    }
    final path = p.join(
      definitions.path,
      'lib',
      'src',
      area,
      '${definitionFileStem(name)}.dart',
    );
    if (File(path).existsSync()) {
      environment.out.writeln('error: $path already exists.');
      return 1;
    }
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(source);
    environment.out.writeln('  created $path');
    return 0;
  }

  String? _areaOf(
    String? requested,
    SpyClass spy,
    BeakGenerateSettings settings,
  ) {
    if (requested != null) {
      return settings.areas.containsKey(requested) ? requested : null;
    }
    if (settings.areas.length == 1) return settings.areas.keys.single;
    final parent = p.posix.basename(p.posix.dirname(spy.path));
    return settings.areas.containsKey(parent) ? parent : null;
  }
}
