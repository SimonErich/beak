import 'package:beak_core/beak_core.dart';
import 'package:worm/worm.dart';

/// The worm field companion for [column], typed by the column's value kind:
/// numeric and timestamp columns get comparable fields, text-like columns
/// (including enums, which persist by name) get string fields, and opaque
/// columns fall back to plain fields.
// --8<-- [start:wormFieldForColumn]
Field<Object?> wormFieldForColumn(BeakColumn column) => switch (column) {
  BeakIntColumn() || BeakDecimalColumn() => ComparableField<num>(column.key),
  BeakDateTimeColumn() => ComparableField<DateTime>(column.key),
  BeakStringColumn() ||
  BeakTextColumn() ||
  BeakRichTextColumn() ||
  BeakColorColumn() ||
  BeakFileColumn() ||
  BeakImageColumn() ||
  BeakEnumColumn() => StringField(column.key),
  BeakBoolColumn() => Field<bool>(column.key),
  BeakJsonColumn() || BeakCustomColumn() => Field<Object>(column.key),
};
// --8<-- [end:wormFieldForColumn]

/// The numeric worm field for [column], as required by sum/avg pushdown.
///
/// Throws a [BeakConfigurationException] for non-numeric columns.
Field<num> wormNumericFieldForColumn(BeakColumn column) => switch (column) {
  BeakIntColumn() || BeakDecimalColumn() => ComparableField<num>(column.key),
  _ => throw BeakConfigurationException(
    'Column "${column.key}" (${column.runtimeType}) is not numeric; '
    'sum/avg aggregate int or decimal columns.',
  ),
};
