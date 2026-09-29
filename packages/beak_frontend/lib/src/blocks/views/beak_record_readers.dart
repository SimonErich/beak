part of '../beak_block_host.dart';

/// Typed field readers shared by the data-bound module views: each resolves
/// a bound [BeakColumn] against a [BeakRecord] by the column's key, so a view
/// never touches a raw field string.

/// The page module views fetch: comfortably above any bounded module dataset,
/// so a board, transcript, inbox, or plan grid never renders a silently
/// truncated page (`BeakQuerySpec` defaults to 25 rows per page).
const BeakPagination _modulePage = BeakPagination(perPage: 500);

/// The string value of [column] in [record], or `null` when unbound or empty.
String? _readString(BeakRecord record, BeakColumn? column) {
  if (column == null) {
    return null;
  }
  return record[column.key]?.raw?.toString();
}

/// Whether [column]'s value in [record] is boolean `true`; `false` when
/// unbound.
bool _readBool(BeakRecord record, BeakColumn? column) =>
    column != null && record[column.key]?.raw == true;

/// The [DateTime] value of [column] in [record], parsing ISO strings, or
/// `null` when unbound or unparseable.
DateTime? _readDateTime(BeakRecord record, BeakColumn? column) {
  if (column == null) {
    return null;
  }
  return switch (record[column.key]?.raw) {
    final DateTime value => value,
    final String value => DateTime.tryParse(value),
    _ => null,
  };
}

/// The integer value of [column] in [record], or `null` when unbound.
int? _readInt(BeakRecord record, BeakColumn? column) {
  if (column == null) {
    return null;
  }
  return switch (record[column.key]?.raw) {
    final int value => value,
    final num value => value.toInt(),
    final String value => int.tryParse(value),
    _ => null,
  };
}

/// The double value of [column] in [record], or `null` when unbound.
double? _readDouble(BeakRecord record, BeakColumn? column) {
  if (column == null) {
    return null;
  }
  return switch (record[column.key]?.raw) {
    final num value => value.toDouble(),
    final String value => double.tryParse(value),
    _ => null,
  };
}

/// Resolves a semantic [BeakColor] to a concrete theme color, or `null` when
/// [color] is unset.
// --8<-- [start:resolveBeakColor]
Color? _resolveBeakColor(BuildContext context, BeakColor? color) {
  final colors = context.colors;
  return switch (color) {
    null => null,
    BeakColor.primary => colors.primary.base,
    BeakColor.secondary => colors.accent.base,
    BeakColor.success => colors.success.base,
    BeakColor.warning => colors.warning.base,
    BeakColor.error => colors.error.base,
    BeakColor.info => colors.info.base,
    BeakColor.muted => colors.textMuted,
  };
}
// --8<-- [end:resolveBeakColor]
