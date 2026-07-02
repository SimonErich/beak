part of 'beak_column.dart';

/// A single-line string column, rendered as plain text everywhere.
final class BeakStringColumn extends BeakColumn {
  /// Creates a single-line string column.
  const BeakStringColumn({
    required super.key,
    required super.label,
    super.visibleOn,
    super.sortable,
    super.searchable,
    super.filterable,
    super.rules,
    this.placeholder = '',
    this.maxLength,
  });

  /// Hint text shown in an empty form input.
  final String placeholder;

  /// Length cap the form input enforces while typing, if any.
  final int? maxLength;

  @override
  BeakRenderConfig get renderConfig =>
      const BeakRenderConfig.uniform(BeakRenderIntent.text);

  @override
  Type get valueType => String;
}
