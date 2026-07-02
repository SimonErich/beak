/// Contract for serializable model objects.
library;

/// Snapshot describing what a [Serializable] wishes to expose.
///
/// The `Serializer` consumes this descriptor to assemble the final
/// JSON output. It is a value snapshot — implementations rebuild it
/// every time [Serializable.describe] is called so each invocation
/// reflects the current model state.
final class SerializationDescriptor {
  /// Creates a [SerializationDescriptor].
  const SerializationDescriptor({
    required this.fields,
    this.hidden = const <String>{},
    this.visible,
    this.appended = const <String, Object?>{},
    this.relations = const <String, Object>{},
  });

  /// Plain column / attribute data to expose.
  final Map<String, Object?> fields;

  /// Field names to drop from the output regardless of inclusion.
  final Set<String> hidden;

  /// Whitelist of field names to include. When non-null, only these
  /// fields appear in the output (subject to [hidden] subtraction).
  final Set<String>? visible;

  /// Computed attributes appended after the main fields.
  final Map<String, Object?> appended;

  /// Related serializables keyed by relation name. Each value is
  /// either a [Serializable] or a `List<Serializable>`.
  final Map<String, Object> relations;
}

/// Implemented by any object that the `Serializer` can render.
abstract class Serializable {
  /// Stable identifier used by cycle detection. Two instances with
  /// the same id are treated as the same node.
  String get serializationId;

  /// A stable type tag used when collapsing cycles into id
  /// references (e.g. `'User'`).
  String get serializationType;

  /// Build the snapshot describing this object's contribution to
  /// the output JSON.
  SerializationDescriptor describe();
}
