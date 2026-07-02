/// User-defined attribute cast built from inline closures.
library;

import '../attribute_cast.dart';

/// An [AttributeCast] assembled from inline `fromDb` / `toDb`
/// closures, for one-off conversions that don't warrant a dedicated
/// cast class.
///
/// ```dart
/// @Column(cast: CustomCast<Color>(
///   fromDb: (raw) => Color.fromHex(raw! as String),
///   toDb: (color) => color.toHex(),
/// ))
/// Color themeColor;
/// ```
///
/// `null` short-circuits in both directions, so the closures only ever
/// receive non-null values.
final class CustomCast<T> extends AttributeCast {
  /// Creates a [CustomCast] from [fromDb] (decode) and [toDb] (encode)
  /// closures.
  const CustomCast({
    required T Function(Object? raw) fromDb,
    required Object? Function(T value) toDb,
    String name = 'custom',
  }) : _fromDb = fromDb,
       _toDb = toDb,
       _name = name;

  final T Function(Object? raw) _fromDb;
  final Object? Function(T value) _toDb;
  final String _name;

  @override
  String get name => _name;

  @override
  Object? decode(Object? raw) => raw == null ? null : _fromDb(raw);

  @override
  Object? encode(Object? value) {
    if (value == null) return null;
    if (value case final T typed) return _toDb(typed);
    throw castError(
      field: name,
      source: value,
      reason: 'CustomCast expected a value of type $T',
      targetType: '$T',
    );
  }
}
