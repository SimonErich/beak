import '../schema/beak_schema_ir.dart';

/// The translations one generated model carries, each keyed by language code.
final class BeakSchemaLabels {
  /// Collects a model's translations.
  const BeakSchemaLabels({
    this.one = const {},
    this.other = const {},
    this.fields = const {},
    this.hints = const {},
    this.values = const {},
    this.actions = const {},
    this.actionDescriptions = const {},
  });

  /// What one record is called.
  final Map<String, String> one;

  /// What several records are called.
  final Map<String, String> other;

  /// Column and relationship labels, by Dart field name.
  final Map<String, Map<String, String>> fields;

  /// Column help texts, by Dart field name.
  final Map<String, Map<String, String>> hints;

  /// Enum value labels of an enum column, by field name, then language, then
  /// value name.
  final Map<String, Map<String, Map<String, String>>> values;

  /// Command labels, by command name.
  final Map<String, Map<String, String>> actions;

  /// Command descriptions, by command name.
  final Map<String, Map<String, String>> actionDescriptions;

  /// Whether the model itself has a name or command label to emit.
  bool get hasModelLabels =>
      one.isNotEmpty ||
      other.isNotEmpty ||
      actions.isNotEmpty ||
      actionDescriptions.isNotEmpty;
}

/// Every model's translations, and the language generated defaults use.
final class BeakProjectLabels {
  /// Collects [bySchema], keyed by schema class name.
  const BeakProjectLabels({this.template, this.bySchema = const {}});

  /// A project without label files.
  static const none = BeakProjectLabels();

  /// The language whose texts become the generated default labels.
  final String? template;

  /// Translations by schema class name.
  final Map<String, BeakSchemaLabels> bySchema;

  /// The translations of [schema], empty when it has none.
  BeakSchemaLabels of(BeakSchemaIr schema) =>
      bySchema[schema.className] ?? const BeakSchemaLabels();
}
