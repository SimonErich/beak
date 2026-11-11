import 'dart:io';

import 'package:path/path.dart' as p;

import '../schema/beak_schema_ir.dart';
import 'label_catalog.dart';
import 'label_resolver.dart';
import 'label_settings.dart';
import 'project_labels.dart';

/// Reads the label files `beak.yaml` points at and resolves them for
/// [schemas]; `beak prepare`, `beak generate` and `beak doctor` share it, so
/// the parts they write and check carry the same labels.
///
/// Without a `labels:` section, nothing is read and the models keep their
/// generated labels. Issue paths are relative to [root].
BeakLabelResolution loadProjectLabels({
  required Directory root,
  required BeakLabelSettings? settings,
  required List<BeakSchemaIr> schemas,
  Map<String, List<String>> enumValues = const {},
}) {
  if (settings == null) {
    return const BeakLabelResolution(BeakProjectLabels.none, [], []);
  }
  final directory = Directory(p.join(root.path, settings.path));
  if (!directory.existsSync()) {
    return BeakLabelResolution(BeakProjectLabels.none, [
      BeakLabelIssue(
        'beak.yaml',
        'labels names ${settings.path}, which does not exist. Create it '
            'with one models_<locale>.arb file per language.',
      ),
    ], const []);
  }
  try {
    return resolveBeakLabels(
      catalog: BeakLabelCatalog.read(directory, template: settings.template),
      schemas: schemas,
      require: settings.require,
      enumValues: enumValues,
      path: settings.path,
    );
  } on BeakLabelCatalogException catch (error) {
    return BeakLabelResolution(BeakProjectLabels.none, [
      for (final issue in error.issues)
        BeakLabelIssue(p.join(settings.path, issue.path), issue.message),
    ], const []);
  }
}

/// The label files of [settings] under [root], for input stamps.
List<File> projectLabelFiles(Directory root, BeakLabelSettings? settings) {
  if (settings == null) return const [];
  final directory = Directory(p.join(root.path, settings.path));
  if (!directory.existsSync()) return const [];
  return [
    for (final entity in directory.listSync())
      if (entity is File && entity.path.endsWith('.arb')) entity,
  ];
}
