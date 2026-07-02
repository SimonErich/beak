part of 'beak_column.dart';

/// Opaque identifier linking a [BeakCustomColumn] to the renderer registered
/// for it in `beak_frontend`.
@immutable
final class BeakColumnTag {
  /// Creates a tag identified by [value].
  const BeakColumnTag(this.value);

  /// Unique identity of the custom renderer.
  final String value;

  @override
  bool operator ==(Object other) =>
      other is BeakColumnTag && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'BeakColumnTag($value)';
}

/// The escape hatch: a column rendered by a custom builder registered in
/// `beak_frontend` under [tag].
final class BeakCustomColumn extends BeakColumn {
  /// Creates a custom column rendered by the builder registered under [tag].
  const BeakCustomColumn({
    required super.key,
    required super.label,
    required this.tag,
    super.visibleOn,
    super.sortable,
    super.searchable,
    super.filterable,
    super.rules,
  });

  /// Identifies the registered custom renderer.
  final BeakColumnTag tag;

  @override
  BeakRenderConfig get renderConfig =>
      const BeakRenderConfig.uniform(BeakRenderIntent.custom);

  /// Custom columns carry opaque values; the registered builder decides.
  @override
  Type get valueType => Object;
}
