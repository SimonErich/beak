part of 'beak_column.dart';

/// A column over a Dart enum [T], rendered as a colored badge in tables and
/// a select control in forms.
///
/// The generic parameter keeps the whole column type-safe: [values],
/// [defaultValue], [badgeColors], and [labelOf] all speak in [T], so there
/// are no stringly-typed states. Map each value to a [BeakColor] for its
/// badge, and (optionally) a [labelOf] for prettier text than the enum's
/// `name`.
///
/// ```dart
/// enum ProductStatus { draft, published, archived }
///
/// static const status = BeakEnumColumn<ProductStatus>(
///   key: 'status',
///   label: 'Status',
///   values: ProductStatus.values,
///   defaultValue: ProductStatus.draft,
///   filterable: true,
///   badgeColors: {
///     ProductStatus.draft: BeakColor.muted,
///     ProductStatus.published: BeakColor.success,
///     ProductStatus.archived: BeakColor.warning,
///   },
/// );
/// ```
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

  /// Returns the declared value whose `name` matches [name], or `null` when
  /// none does — the one way wire strings (query params, stored rows) decode
  /// back into typed enum values without an `as` cast.
  T? valueByName(String name) {
    for (final option in values) {
      if (option.name == name) {
        return option;
      }
    }
    return null;
  }

  @override
  BeakRenderConfig get renderConfig =>
      const BeakRenderConfig.uniform(BeakRenderIntent.badge);

  @override
  Type get valueType => T;
}
