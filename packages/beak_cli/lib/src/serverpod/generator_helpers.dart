part of 'generator.dart';

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
