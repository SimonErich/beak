import 'dart:io';

import 'package:args/args.dart';
import 'package:beak_serverpod_generator/beak_serverpod_generator.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Generates typed model companions and endpoint bindings; never migrations.
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('config', defaultsTo: 'beak_serverpod.yaml')
    ..addOption('root')
    ..addOption('client');
  try {
    final options = parser.parse(arguments);
    final configPath = options.option('config')!;
    final file = File(configPath);
    final Object? document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap) {
      throw const FormatException('Expected a YAML object.');
    }
    final Object? library = document['library'];
    final Object? types = document['types'] ?? const <String>[];
    final Object? models = document['models'] ?? const <String>[];
    final Object? output = document['output'];
    final Object? configuredClient = document['client'] ?? 'Client';
    final String client = options.option('client') ?? '$configuredClient';
    if (library is! String ||
        types is! List ||
        models is! List ||
        output is! String ||
        configuredClient is! String ||
        types.any((Object? value) => value is! String) ||
        models.any((Object? value) => value is! String) ||
        (types.isEmpty && models.isEmpty)) {
      throw const FormatException(
        'Provide library, models or types (string lists), output, and '
        'optionally the client class name.',
      );
    }
    final root = p.absolute(
      options.option('root') ?? p.dirname(file.absolute.path),
    );
    final contents = await generateServerpodCompanions(
      packageRoot: root,
      library: library,
      models: [
        for (final Object? name in models)
          if (name is String) name,
      ],
      types: [
        for (final Object? name in types)
          if (name is String) name,
      ],
      client: client,
    );
    final target = File(p.join(root, output));
    if (target.existsSync() && target.readAsStringSync() == contents) {
      stdout.writeln('Up to date ${target.path}');
    } else {
      target.parent.createSync(recursive: true);
      target.writeAsStringSync(contents);
      stdout.writeln('Generated ${target.path}');
    }
  } on Exception catch (error) {
    stderr.writeln('Companion generation failed: $error');
    exitCode = 1;
  }
}
