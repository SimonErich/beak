/// Arbitrary-precision decimal value.
library;

/// Lossless decimal value backed by its canonical string form.
///
/// [Decimal] preserves the exact textual representation of a decimal
/// number so values such as `0.10000000000000001` survive
/// round-tripping through a database column or JSON payload without
/// floating-point drift.
///
/// Construction is strict: [Decimal.parse] throws [FormatException]
/// on input that is not a finite decimal. The accepted grammar is:
///
/// ```text
/// sign?  integer-part  ('.' fractional-part)?  exponent?
/// ```
final class Decimal implements Comparable<Decimal> {
  const Decimal._(this._value);

  /// Parses [source] as a decimal value.
  factory Decimal.parse(String source) {
    if (!_pattern.hasMatch(source)) {
      throw FormatException('Invalid decimal: $source', source);
    }
    return Decimal._(_canonicalize(source));
  }

  /// Returns a [Decimal] for [source], or `null` when it cannot be
  /// parsed.
  static Decimal? tryParse(String source) {
    if (!_pattern.hasMatch(source)) return null;
    return Decimal._(_canonicalize(source));
  }

  /// Builds a [Decimal] from an integer value.
  factory Decimal.fromInt(int value) =>
      Decimal._(_canonicalize(value.toString()));

  /// The zero constant.
  static const Decimal zero = Decimal._('0');

  static final RegExp _pattern = RegExp(r'^[+-]?(\d+)(\.\d+)?([eE][+-]?\d+)?$');

  final String _value;

  /// Canonical string representation of this decimal.
  String get value => _value;

  @override
  int compareTo(Decimal other) =>
      double.parse(_value).compareTo(double.parse(other._value));

  @override
  bool operator ==(Object other) => other is Decimal && other._value == _value;

  @override
  int get hashCode => _value.hashCode;

  @override
  String toString() => _value;

  static String _canonicalize(String raw) {
    var trimmed = raw;
    if (trimmed.startsWith('+')) trimmed = trimmed.substring(1);
    return trimmed;
  }
}
