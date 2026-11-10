import '../schema/beak_schema_emitter.dart';
import '../schema/beak_schema_ir.dart';
import 'label_catalog.dart';
import 'label_settings.dart';
import 'project_labels.dart';

/// What [resolveBeakLabels] found: the translations to emit, and what is
/// wrong or missing in the label files.
final class BeakLabelResolution {
  /// Collects the outcome.
  const BeakLabelResolution(this.labels, this.errors, this.warnings);

  /// Translations per schema.
  final BeakProjectLabels labels;

  /// Problems that stop generation: unknown keys and keys missing in a locale.
  final List<BeakLabelIssue> errors;

  /// Shown fields without a label; errors instead with `require: shown`.
  final List<BeakLabelIssue> warnings;
}

/// Looks up every model, field, relationship, enum value and command of
/// [schemas] in [catalog].
///
/// Keys are paths of Dart names: `placedOrder` (the model, an ICU plural or
/// one text), `placedOrder.email` (a field or relationship),
/// `placedOrder.email.hint`, `placedOrder.actions.cancel` (+ `.description`),
/// `orderStatus.pending` (an enum value) and `*.sortOrder` for every field,
/// relationship or enum value of that name without an exact key. A foreign
/// key without a label takes its belongs-to relationship's.
///
/// A key nobody asked for is a typo, reported with the nearest real key.
///
/// [enumValues] lists the values of enums the schemas name but do not carry,
/// by enum type name (the Serverpod path, whose enums are generated apart).
BeakLabelResolution resolveBeakLabels({
  required BeakLabelCatalog catalog,
  required List<BeakSchemaIr> schemas,
  BeakLabelRequirement require = BeakLabelRequirement.none,
  Map<String, List<String>> enumValues = const {},
  String path = 'labels',
}) => _Resolver(catalog, schemas, enumValues, path).resolve(require);

final class _Resolver {
  _Resolver(this.catalog, this.schemas, this.enumValues, this.path);

  final BeakLabelCatalog catalog;
  final List<BeakSchemaIr> schemas;
  final Map<String, List<String>> enumValues;
  final String path;
  final Set<String> _asked = {};
  final Set<String> _used = {};
  final Map<String, Map<String, List<String>>> _missing = {};

  BeakLabelResolution resolve(BeakLabelRequirement require) {
    final errors = <BeakLabelIssue>[];
    final modelKeys = <String, String>{};
    final bySchema = <String, BeakSchemaLabels>{};
    for (final schema in schemas) {
      final String key = _modelKeyOf(schema);
      if (modelKeys[key] case final other? when other != schema.className) {
        errors.add(
          BeakLabelIssue(
            path,
            '$other and ${schema.className} share the label key "$key"; '
            'give one a labelKey.',
          ),
        );
      }
      modelKeys[key] = schema.className;
      bySchema[schema.className] = _schemaLabels(schema, key);
    }
    errors
      ..addAll(_unknownKeys(modelKeys.keys.toSet()))
      ..addAll(_localeGaps());
    final coverage = [
      for (final MapEntry(:key, :value) in _missing.entries)
        BeakLabelIssue(
          path,
          'no label in $key for: '
          '${[for (final keys in value.values) ...keys].join(', ')}.',
        ),
    ];
    final bool strict = require == BeakLabelRequirement.shown;
    return BeakLabelResolution(
      BeakProjectLabels(template: catalog.template, bySchema: bySchema),
      [...errors, if (strict) ...coverage],
      strict ? const [] : coverage,
    );
  }

  BeakSchemaLabels _schemaLabels(BeakSchemaIr schema, String model) {
    final one = <String, String>{};
    final other = <String, String>{};
    _asked.add(model);
    for (final locale in catalog.locales) {
      final names = catalog.names(locale, model);
      if (names == null) {
        _miss(locale, model, model);
        continue;
      }
      _used.add(model);
      one[locale] = names.one;
      other[locale] = names.other;
    }
    final fields = <String, Map<String, String>>{};
    for (final relation in schema.relations) {
      fields[relation.fieldName] = _texts(model, relation.fieldName);
    }
    for (final name in BeakSchemaEmitter.inverseRelationNamesOf(
      schema,
      schemas,
    )) {
      fields[name] = _texts(model, name, shown: false);
    }
    final hints = <String, Map<String, String>>{};
    final values = <String, Map<String, Map<String, String>>>{};
    for (final column in schema.columns) {
      final bool shown = column.arguments['visibleOn'] != '{}';
      final keyOf = schema.relations
          .where((relation) => relation.foreignKey == column.columnKey)
          .map((relation) => fields[relation.fieldName])
          .firstOrNull;
      final texts = _texts(
        model,
        column.fieldName,
        shown: shown && (keyOf == null || keyOf.isEmpty),
      );
      fields[column.fieldName] = texts.isEmpty && keyOf != null ? keyOf : texts;
      hints[column.fieldName] = _texts(
        model,
        column.fieldName,
        suffix: '.hint',
        shown: false,
      );
      if (column.enumTypeName case final type?) {
        values[column.fieldName] = _enumTexts(
          _lowerCamel(type),
          column.enumValueNames.isEmpty
              ? enumValues[type] ?? const []
              : column.enumValueNames,
          shown: shown,
        );
      }
    }
    final actions = <String, Map<String, String>>{};
    final descriptions = <String, Map<String, String>>{};
    final prefix = '$model.actions.';
    for (final key in catalog.keys.where((key) => key.startsWith(prefix))) {
      _used.add(key);
      final rest = key.substring(prefix.length);
      final bool isDescription = rest.endsWith('.description');
      final name = isDescription
          ? rest.substring(0, rest.length - '.description'.length)
          : rest;
      final target = isDescription ? descriptions : actions;
      for (final locale in catalog.locales) {
        if (catalog.text(locale, key) case final text?) {
          (target[name] ??= {})[locale] = text;
        }
      }
    }
    return BeakSchemaLabels(
      one: one,
      other: other,
      fields: {
        for (final MapEntry(:key, :value) in fields.entries)
          if (value.isNotEmpty) key: value,
      },
      hints: {
        for (final MapEntry(:key, :value) in hints.entries)
          if (value.isNotEmpty) key: value,
      },
      values: {
        for (final MapEntry(:key, :value) in values.entries)
          if (value.isNotEmpty) key: value,
      },
      actions: actions,
      actionDescriptions: descriptions,
    );
  }

  /// The texts of `model.name` (or `*.name`) by locale.
  Map<String, String> _texts(
    String model,
    String name, {
    String suffix = '',
    bool shown = true,
  }) {
    final exact = '$model.$name$suffix';
    final shared = '*.$name$suffix';
    _asked
      ..add(exact)
      ..add(shared);
    final texts = <String, String>{};
    for (final locale in catalog.locales) {
      final String? text = _take(locale, exact) ?? _take(locale, shared);
      if (text != null) {
        texts[locale] = text;
      } else if (shown) {
        _miss(locale, model, exact);
      }
    }
    return texts;
  }

  Map<String, Map<String, String>> _enumTexts(
    String type,
    List<String> values, {
    required bool shown,
  }) {
    final texts = <String, Map<String, String>>{};
    for (final value in values) {
      final exact = '$type.$value';
      final shared = '*.$value';
      _asked
        ..add(exact)
        ..add(shared);
      for (final locale in catalog.locales) {
        final String? text = _take(locale, exact) ?? _take(locale, shared);
        if (text != null) {
          (texts[locale] ??= {})[value] = text;
        } else if (shown) {
          _miss(locale, type, exact);
        }
      }
    }
    return texts;
  }

  String? _take(String locale, String key) {
    final String? text = catalog.text(locale, key);
    if (text != null) _used.add(key);
    return text;
  }

  void _miss(String locale, String group, String key) {
    final keys = (_missing[locale] ??= {})[group] ??= [];
    if (!keys.contains(key)) keys.add(key);
  }

  List<BeakLabelIssue> _unknownKeys(Set<String> modelKeys) => [
    for (final key in catalog.keys.difference(_used).toList()..sort())
      BeakLabelIssue(
        path,
        '"$key" names no model, field, relationship, enum value or action.'
        '${_suggestionFor(key, modelKeys)}',
      ),
  ];

  String _suggestionFor(String key, Set<String> modelKeys) {
    final candidates = key.contains('.actions.')
        ? modelKeys.map((model) => '$model.actions.')
        : _asked;
    String? best;
    int bestDistance = 1 << 30;
    for (final candidate in candidates) {
      final probe = key.contains('.actions.')
          ? key.substring(0, key.indexOf('.actions.') + '.actions.'.length)
          : key;
      final distance = _distance(probe, candidate);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = candidate;
      }
    }
    if (best == null || bestDistance > 3 + key.length ~/ 8) return '';
    return ' Did you mean "$best"?';
  }

  List<BeakLabelIssue> _localeGaps() {
    final known = _used;
    return [
      for (final key in known.toList()..sort())
        for (final locale in catalog.locales)
          if (!catalog.keysOf(locale).contains(key))
            BeakLabelIssue(
              path,
              '"$key" is missing in $locale but present in '
              '${catalog.locales.where((other) => catalog.keysOf(other).contains(key)).join(', ')}.',
            ),
    ];
  }

  String _modelKeyOf(BeakSchemaIr schema) =>
      schema.labelKey ?? _lowerCamel(schema.className);

  static String _lowerCamel(String name) =>
      name.isEmpty ? name : '${name[0].toLowerCase()}${name.substring(1)}';

  static int _distance(String a, String b) {
    var previous = List<int>.generate(b.length + 1, (index) => index);
    for (var i = 1; i <= a.length; i++) {
      final current = [i, ...List<int>.filled(b.length, 0)];
      for (var j = 1; j <= b.length; j++) {
        final int cost = a[i - 1] == b[j - 1] ? 0 : 1;
        current[j] = [
          previous[j] + 1,
          current[j - 1] + 1,
          previous[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      previous = current;
    }
    return previous[b.length];
  }
}
