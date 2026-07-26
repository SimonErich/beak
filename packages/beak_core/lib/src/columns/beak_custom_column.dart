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
///
/// Auto-forms skip custom columns; use this for bespoke cells (a sparkline,
/// a status pill) that no built-in column kind covers. The same [tag] value
/// must be registered on the frontend so the renderer can be located.
///
/// ```dart
/// static const badge = BeakCustomColumn(
///   key: 'badge',
///   label: 'Badge',
///   tag: BeakColumnTag('badge'),
/// );
/// ```
final class BeakCustomColumn extends BeakColumn with BeakTypedColumn<Object> {
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

  /// Reads [value] as-is: a custom column carries an opaque payload.
  @override
  Object? readValue(BeakValue? value) => value?.raw;
}
