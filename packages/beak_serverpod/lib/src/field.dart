import 'package:beak_core/beak_core.dart';

import 'codec.dart';

/// Presentation options, independent of the generated property's data type.
final class ServerpodColumnOptions {
  /// Creates explicit presentation options. Fields default to detail-only.
  const ServerpodColumnOptions({
    this.visibleOn = const {BeakContext.detail},
    this.sortable = false,
    this.searchable = false,
    this.filterable = false,
    this.rules = const [],
    this.enumLabels = const {},
  });

  /// Surfaces deliberately allowed to display or edit the field.
  final Set<BeakContext> visibleOn;

  /// Whether to expose sorting for this field.
  final bool sortable;

  /// Whether to include this field in search.
  final bool searchable;

  /// Whether to offer this field as a filter.
  final bool filterable;

  /// Presentation validation; business rules remain server-owned.
  final List<BeakRule> rules;

  /// Localized display labels for values of the source enum.
  final Map<Enum, String> enumLabels;
}

/// A generated, typed property reference, including nested DTO projections.
final class ServerpodField<T, V> {
  /// Describes a property without redefining the source model.
  const ServerpodField({
    required this.key,
    required this.get,
    required this.codec,
    required this.buildColumn,
  });

  /// Generated path used internally by Beak records and queries.
  final String key;

  /// Reads the original property's statically known type.
  final V Function(T value) get;

  /// Typed wire conversion for this property.
  final ServerpodValueCodec<V> codec;

  /// Generates the matching column kind without repeating its type in app code.
  final BeakColumn Function(String label, ServerpodColumnOptions options)
  buildColumn;

  /// The field's column, with localized text and intentional exposure.
  BeakColumn column(
    String label, {
    ServerpodColumnOptions options = const ServerpodColumnOptions(),
  }) => buildColumn(label, options);

  /// Whether the input includes this field, independently of explicit null.
  bool isPresent(BeakRecord record) => record.values.containsKey(key);

  /// Reads typed submitted input and associates validation with this field.
  V read(BeakRecord record) {
    try {
      return codec.decode(record[key]);
    } on BeakValidationException catch (error) {
      throw BeakValidationException(
        error.message,
        fieldErrors: {
          key: [error.message],
        },
      );
    }
  }

  /// Requires the field to be supplied, while still allowing an explicit null.
  V readRequired(BeakRecord record) {
    if (!isPresent(record)) {
      throw BeakValidationException(
        'A required input is missing.',
        fieldErrors: {
          key: ['This value must be supplied.'],
        },
      );
    }
    return read(record);
  }

  /// Encodes this property of the source object.
  BeakValue encode(T value) => codec.encode(get(value));
}

/// Typed access to a nested object or object list in a loaded DTO record.
///
/// Relations are presentation references, not independently writable resources.
final class ServerpodRelationField<T, V> {
  /// Creates a generated relation reference.
  const ServerpodRelationField({
    required this.key,
    required this.get,
    required this.codec,
  });

  /// Generated property path for custom presentation columns.
  final String key;

  /// Reads the original nested object's statically known type.
  final V Function(T value) get;

  /// Reconstructs the existing source DTO from a complete loaded record.
  final ServerpodCodec<T> codec;

  /// Reads a relation from a complete record returned by the resource.
  V read(BeakRecord record) => get(codec.decode(record));
}

/// Builds command presentation from the uniquely corresponding read column.
///
/// Overrides carry localized labels only; source DTO types remain generated.
BeakColumn serverpodFormColumn<T, V>(
  ServerpodField<T, V> field,
  List<BeakColumn> columns, {
  String? label,
}) {
  final exact = columns.where((column) => column.key == field.key).firstOrNull;
  final leaf = field.key.split('.').last;
  final matches = columns
      .where((column) => column.key.split('.').last == leaf)
      .toList();
  final source = exact ?? (matches.length == 1 ? matches.single : null);
  final labels = <Enum, String>{};
  if (source case BeakEnumColumn<Enum>()) {
    for (final value in source.values) {
      labels[value] = source.labelFor(value);
    }
  }
  return field.column(
    label ?? source?.label ?? leaf,
    options: ServerpodColumnOptions(
      visibleOn: const {BeakContext.form},
      enumLabels: labels,
    ),
  );
}
