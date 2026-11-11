import 'package:yaml/yaml.dart';

/// How strictly `beak generate` and `beak prepare` expect a label for every
/// shown model, field, relationship and enum value.
enum BeakLabelRequirement {
  /// A missing label is a warning; the field keeps its generated label.
  none,

  /// A missing label for a shown field fails the run.
  shown,
}

/// The `labels:` section of `beak.yaml`: where the label files are.
///
/// ```yaml
/// labels: labels                  # the folder, relative to beak.yaml
/// labels:
///   path: labels
///   template: de                  # the language generated defaults use
///   require: shown                # fail on a shown field without a label
/// ```
final class BeakLabelSettings {
  /// Reads label files from [path].
  const BeakLabelSettings({
    required this.path,
    this.template,
    this.require = BeakLabelRequirement.none,
  });

  /// The folder of `*.arb` label files, relative to `beak.yaml`.
  final String path;

  /// The language generated default labels use; the first by name otherwise.
  final String? template;

  /// Whether a missing label warns or fails.
  final BeakLabelRequirement require;

  /// Parses the `labels:` value of `beak.yaml`; `null` when absent.
  ///
  /// Throws a [FormatException] naming the offending key.
  static BeakLabelSettings? parse(Object? value) {
    if (value == null) return null;
    if (value is String) return BeakLabelSettings(path: value);
    if (value is! YamlMap) {
      throw const FormatException(
        'labels: expected a folder path or a map with path, template and '
        'require.',
      );
    }
    for (final Object? key in value.keys) {
      if (!const {'path', 'template', 'require'}.contains(key)) {
        throw FormatException(
          'unknown key "labels.$key". Expected one of: path, template, require.',
        );
      }
    }
    final Object? path = value['path'];
    if (path is! String || path.isEmpty) {
      throw const FormatException('labels.path: expected a folder path.');
    }
    final Object? template = value['template'];
    if (template != null && template is! String) {
      throw const FormatException('labels.template: expected a locale.');
    }
    final Object? require = value['require'];
    final BeakLabelRequirement requirement = switch (require) {
      null || 'none' => BeakLabelRequirement.none,
      'shown' => BeakLabelRequirement.shown,
      _ => throw const FormatException(
        'labels.require: expected "none" or "shown".',
      ),
    };
    return BeakLabelSettings(
      path: path,
      template: template is String ? template : null,
      require: requirement,
    );
  }
}
