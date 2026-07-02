/// Base contract for attribute casts.
library;

import '../exception/cast_exception.dart';

/// Bidirectional conversion between a Dart domain value and the
/// primitive representation an adapter stores.
///
/// The interface is intentionally non-generic so a `CastManager` can
/// hold a heterogeneous map of casts. Concrete subclasses are
/// strongly typed and add typed convenience APIs as needed.
abstract class AttributeCast {
  /// Creates an [AttributeCast].
  const AttributeCast();

  /// Stable identifier for the cast.
  String get name;

  /// Lift a raw stored value into the domain type.
  ///
  /// Returns `null` when [raw] is `null`. Implementations throw
  /// [CastException] when [raw] is not in an accepted form.
  Object? decode(Object? raw);

  /// Serialize a domain value into its stored representation.
  ///
  /// Returns `null` when [value] is `null`. Implementations throw
  /// [CastException] when [value] is not of the expected type.
  Object? encode(Object? value);

  /// Helper to build a [CastException] for the cast.
  CastException castError({
    required String field,
    required Object? source,
    required String reason,
    required String targetType,
  }) => CastException(
    field: field,
    fromType: _typeOf(source),
    toType: targetType,
    message: reason,
  );

  static String _typeOf(Object? value) {
    if (value == null) return 'Null';
    if (value is String) return 'String';
    if (value is int) return 'int';
    if (value is double) return 'double';
    if (value is num) return 'num';
    if (value is bool) return 'bool';
    if (value is DateTime) return 'DateTime';
    if (value is Uri) return 'Uri';
    if (value is BigInt) return 'BigInt';
    if (value is List<Object?>) return 'List';
    if (value is Map<Object?, Object?>) return 'Map';
    return 'Object';
  }
}
