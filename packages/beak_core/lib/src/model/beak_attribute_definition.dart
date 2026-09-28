import '../common/beak_exception.dart';
import '../rules/beak_rule.dart';

/// Interpretation of a configurable attribute stored as a canonical string.
enum BeakAttributeType {
  /// Arbitrary text.
  text,

  /// A finite decimal number.
  number,

  /// Exactly `true` or `false`.
  boolean,

  /// One of the definition's explicit choices.
  choice,
}

/// Shared metadata driving an attribute editor and authoritative validation.
final class BeakAttributeDefinition {
  /// Defines one versioned attribute without coupling it to a database schema.
  BeakAttributeDefinition({
    required this.id,
    required this.label,
    required this.type,
    this.required = false,
    List<String> choices = const [],
    this.version = 1,
    this.description,
    this.rules = const [],
  }) : choices = List.unmodifiable(choices) {
    if (id.isEmpty ||
        label.isEmpty ||
        version < 1 ||
        (type == BeakAttributeType.choice && choices.isEmpty) ||
        choices.any((choice) => choice.trim().isEmpty) ||
        choices.toSet().length != choices.length) {
      throw const BeakConfigurationException('Invalid attribute definition.');
    }
  }

  /// Stable definition identity, independent of its display label.
  final String id;

  /// Display label inherited by inputs.
  final String label;

  /// Storage interpretation shared by client and server.
  final BeakAttributeType type;

  /// Whether a nonempty value is required.
  final bool required;

  /// Complete allowed values for a choice attribute.
  final List<String> choices;

  /// Revision required by stored values after a definition changes meaning.
  final int version;

  /// Optional editor guidance.
  final String? description;

  /// Additional validation applied to the canonical stored value.
  final List<BeakRule> rules;

  /// Validates both the representation and optional stored definition revision.
  String? validate(String? value, {int? version}) {
    if (version != null && version != this.version) {
      return 'Review this value because its attribute definition changed.';
    }
    if (value == null || value.trim().isEmpty) {
      return required ? '$label is required.' : null;
    }
    final invalid = switch (type) {
      BeakAttributeType.text => false,
      BeakAttributeType.number => !(double.tryParse(value)?.isFinite ?? false),
      BeakAttributeType.boolean => value != 'true' && value != 'false',
      BeakAttributeType.choice => !choices.contains(value),
    };
    if (invalid) return 'Enter a valid ${type.name} value for $label.';
    for (final rule in rules) {
      final error = rule.validate(switch (type) {
        BeakAttributeType.number => double.parse(value),
        BeakAttributeType.boolean => value == 'true',
        _ => value,
      });
      if (error != null) return error;
    }
    return null;
  }
}

/// One stored or proposed value associated with a definition revision.
final class BeakAttributeEntry {
  /// Creates an attribute value without changing its representation.
  const BeakAttributeEntry({
    required this.definitionId,
    required this.value,
    required this.version,
  });

  /// Stable definition identity.
  final String definitionId;

  /// Canonical value, or null for an incomplete draft.
  final String? value;

  /// Definition revision under which this value was entered.
  final int version;
}

/// A non-destructive comparison between values and current definitions.
final class BeakAttributeReconciliation {
  /// Captures retained values, required omissions and actionable errors.
  const BeakAttributeReconciliation({
    required this.retained,
    required this.obsolete,
    required this.missing,
    required this.errors,
  });

  /// Values still belonging to this definition set, including invalid ones.
  final List<BeakAttributeEntry> retained;

  /// Values whose definitions are no longer present; never silently deleted.
  final List<BeakAttributeEntry> obsolete;

  /// Required definitions without a value row.
  final List<BeakAttributeDefinition> missing;

  /// Problems keyed by stable definition identity.
  final Map<String, List<String>> errors;

  /// Whether the values can be accepted under the current definitions.
  bool get valid => obsolete.isEmpty && missing.isEmpty && errors.isEmpty;
}

/// Reconciles a category's definitions without silently reinterpreting values.
final class BeakAttributeSet {
  /// Captures an immutable definition set with unique identities.
  BeakAttributeSet(Iterable<BeakAttributeDefinition> definitions)
    : definitions = List.unmodifiable(definitions) {
    if (this.definitions.map((definition) => definition.id).toSet().length !=
        this.definitions.length) {
      throw const BeakConfigurationException(
        'Attribute identities must be unique.',
      );
    }
  }

  /// Definitions in presentation order.
  final List<BeakAttributeDefinition> definitions;

  /// Reports compatible, obsolete, missing, duplicate and invalid values.
  BeakAttributeReconciliation reconcile(Iterable<BeakAttributeEntry> entries) {
    final byId = {
      for (final definition in definitions) definition.id: definition,
    };
    final seen = <String>{};
    final retained = <BeakAttributeEntry>[];
    final obsolete = <BeakAttributeEntry>[];
    final errors = <String, List<String>>{};
    for (final entry in entries) {
      final definition = byId[entry.definitionId];
      if (definition == null) {
        obsolete.add(entry);
        continue;
      }
      retained.add(entry);
      if (!seen.add(entry.definitionId)) {
        errors
            .putIfAbsent(entry.definitionId, () => [])
            .add('This attribute appears more than once.');
      }
      final error = definition.validate(entry.value, version: entry.version);
      if (error != null) {
        errors.putIfAbsent(entry.definitionId, () => []).add(error);
      }
    }
    return BeakAttributeReconciliation(
      retained: List.unmodifiable(retained),
      obsolete: List.unmodifiable(obsolete),
      missing: List.unmodifiable(
        definitions.where(
          (definition) => definition.required && !seen.contains(definition.id),
        ),
      ),
      errors: Map.unmodifiable({
        for (final entry in errors.entries)
          entry.key: List<String>.unmodifiable(entry.value),
      }),
    );
  }
}
