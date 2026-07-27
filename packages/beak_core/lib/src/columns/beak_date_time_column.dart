part of 'beak_column.dart';

/// How a [BeakDateTimeColumn] formats its value for display.
enum BeakDateFormat {
  /// Locale-aware absolute date and time.
  standard,

  /// Humanized relative timestamp ("3 days ago").
  relative,

  /// Date part only.
  dateOnly,

  /// Time part only.
  timeOnly,

  /// ISO-8601 string.
  iso,
}

/// A date/time column.
///
/// Tables and detail views follow [format] (rendering relatively for
/// [BeakDateFormat.relative]); forms and filters always use an absolute
/// date picker.
///
/// ```dart
/// static const updatedAt = BeakDateTimeColumn(
///   key: 'updated_at',
///   label: 'Updated',
///   format: BeakDateFormat.relative,
///   sortable: true,
///   visibleOn: {BeakContext.table, BeakContext.detail},
/// );
/// ```
final class BeakDateTimeColumn extends BeakColumn
    with BeakTypedColumn<DateTime> {
  /// Creates a date/time column displayed with [format].
  const BeakDateTimeColumn({
    required super.key,
    required super.label,
    super.visibleOn,
    super.sortable,
    super.searchable,
    super.filterable,
    super.indexed,
    super.unique,
    super.rules,
    this.format = BeakDateFormat.standard,
  });

  /// Display format used in tables and detail views.
  final BeakDateFormat format;

  /// Returns a copy of this column displaying with [format] instead, keeping
  /// every other property (key, label, visibility, rules) unchanged.
  BeakDateTimeColumn withFormat(BeakDateFormat format) => BeakDateTimeColumn(
    key: key,
    label: label,
    visibleOn: visibleOn,
    sortable: sortable,
    searchable: searchable,
    filterable: filterable,
    rules: rules,
    format: format,
  );

  BeakRenderIntent get _displayIntent => format == BeakDateFormat.relative
      ? BeakRenderIntent.relativeDate
      : BeakRenderIntent.date;

  @override
  BeakRenderConfig get renderConfig => BeakRenderConfig(
    table: _displayIntent,
    form: BeakRenderIntent.date,
    detail: _displayIntent,
    filter: BeakRenderIntent.date,
  );

  /// Reads [value] as a datetime value.
  @override
  DateTime? readValue(BeakValue? value) => _readDateTime(value);
}
