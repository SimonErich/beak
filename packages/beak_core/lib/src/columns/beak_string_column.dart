part of 'beak_column.dart';

/// A single-line string column, rendered as plain text everywhere.
///
/// The workhorse column for names, references, and foreign keys. [maxLength]
/// caps typing in the form; [placeholder] hints an empty input.
///
/// ```dart
/// static const name = BeakStringColumn(
///   key: 'name',
///   label: 'Name',
///   placeholder: 'A headline',
///   searchable: true,
///   sortable: true,
///   rules: [BeakRequired(), BeakMaxLength(255)],
/// );
/// ```
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
