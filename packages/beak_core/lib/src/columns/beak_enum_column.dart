part of 'beak_column.dart';

/// A column over a Dart enum [T], rendered as a colored badge.
final class BeakEnumColumn<T extends Enum> extends BeakColumn {
  /// Creates an enum column offering [values].
  const BeakEnumColumn({
    required super.key,
    required super.label,
    required this.values,
    super.visibleOn,
    super.sortable,
    super.searchable,
    super.filterable,
    super.rules,
    this.defaultValue,
    this.badgeColors = const <Never, BeakColor>{},
    this.labelOf,
  });

  /// All selectable values (typically `MyEnum.values`).
  final List<T> values;

  /// Pre-selected value in create forms, if any.
  final T? defaultValue;

  /// Badge color per value; unmapped values use the theme default.
  final Map<T, BeakColor> badgeColors;

  /// Custom display labeller; defaults to the enum's `name`.
  final String Function(T value)? labelOf;

  /// The badge color configured for [value], or `null` when unmapped.
  BeakColor? badgeColorFor(T value) => badgeColors[value];

  /// The display label of [value]: [labelOf] when set, else `value.name`.
  String labelFor(T value) => labelOf?.call(value) ?? value.name;

  @override
  BeakRenderConfig get renderConfig =>
      const BeakRenderConfig.uniform(BeakRenderIntent.badge);

  @override
  Type get valueType => T;
}
