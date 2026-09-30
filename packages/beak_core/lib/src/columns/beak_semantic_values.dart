import 'package:meta/meta.dart';

/// A calendar date without a time, offset, or timezone.
@immutable
final class BeakDate implements Comparable<BeakDate> {
  /// Creates a valid Gregorian date. Years are restricted to ISO's four digits.
  const BeakDate(this.year, this.month, this.day)
    : assert(year >= 1 && year <= 9999),
      assert(month >= 1 && month <= 12),
      assert(day >= 1 && day <= 31),
      assert(
        month != 4 && month != 6 && month != 9 && month != 11 || day <= 30,
      ),
      assert(
        month != 2 ||
            day <= 28 ||
            day == 29 && year % 4 == 0 && (year % 100 != 0 || year % 400 == 0),
      );

  /// Gregorian year.
  final int year;

  /// Calendar month, 1–12.
  final int month;

  /// Day of the month, 1–31.
  final int day;

  /// Parses exactly `YYYY-MM-DD`, rejecting overflow rather than normalizing it.
  factory BeakDate.parse(String source) =>
      tryParse(source) ??
      (throw FormatException(
        'Expected a valid calendar date (YYYY-MM-DD).',
        source,
      ));

  /// Parses a date, or returns null for malformed or impossible dates.
  static BeakDate? tryParse(String source) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(source);
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return BeakDate(year, month, day);
  }

  /// Extracts the displayed calendar components; never converts timezones.
  factory BeakDate.fromDateTime(DateTime value) =>
      BeakDate(value.year, value.month, value.day);

  /// A local midnight for calendar UI adapters; no persistence conversion.
  DateTime toDateTime() => DateTime(year, month, day);

  @override
  int compareTo(BeakDate other) => toString().compareTo(other.toString());
  @override
  bool operator ==(Object other) =>
      other is BeakDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;
  @override
  int get hashCode => Object.hash(year, month, day);
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

/// A wall-clock time without an associated calendar date or timezone.
@immutable
final class BeakTime implements Comparable<BeakTime> {
  /// Creates a time; [microsecond] is the fractional part of the whole second.
  const BeakTime(
    this.hour,
    this.minute, {
    this.second = 0,
    this.microsecond = 0,
  }) : assert(hour >= 0 && hour < 24),
       assert(minute >= 0 && minute < 60),
       assert(second >= 0 && second < 60),
       assert(microsecond >= 0 && microsecond < 1000000);

  /// Hour, 0–23.
  final int hour;

  /// Minute, 0–59.
  final int minute;

  /// Second, 0–59; leap seconds are not represented.
  final int second;

  /// Fractional microseconds, 0–999999.
  final int microsecond;

  /// Parses `HH:mm`, `HH:mm:ss`, or up to six fractional digits.
  factory BeakTime.parse(String source) =>
      tryParse(source) ??
      (throw FormatException(
        'Expected a valid time (HH:mm[:ss[.ffffff]]).',
        source,
      ));

  /// Parses a time, returning null for offsets and out-of-range components.
  static BeakTime? tryParse(String source) {
    final match = RegExp(
      r'^(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,6}))?)?$',
    ).firstMatch(source);
    if (match == null) return null;
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    final second = int.parse(match[3] ?? '0');
    final microsecond = int.parse((match[4] ?? '').padRight(6, '0'));
    if (hour >= 24 || minute >= 60 || second >= 60) return null;
    return BeakTime(hour, minute, second: second, microsecond: microsecond);
  }

  /// Microseconds elapsed since midnight, useful for exact ordering.
  int get microsecondsSinceMidnight =>
      ((hour * 60 + minute) * 60 + second) * 1000000 + microsecond;
  @override
  int compareTo(BeakTime other) =>
      microsecondsSinceMidnight.compareTo(other.microsecondsSinceMidnight);
  @override
  bool operator ==(Object other) =>
      other is BeakTime &&
      microsecondsSinceMidnight == other.microsecondsSinceMidnight;
  @override
  int get hashCode => microsecondsSinceMidnight.hashCode;
  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}${microsecond == 0 ? '' : '.${microsecond.toString().padLeft(6, '0')}'}';
}

/// How a fractional count of storage units becomes a whole one.
///
/// Money that is averaged or divided has no exact answer, so Beak never picks
/// a mode for you: name the one your ledger uses.
enum BeakRounding {
  /// Toward negative infinity: 10.5 becomes 10, -10.5 becomes -11.
  floor,

  /// Toward positive infinity: 10.5 becomes 11, -10.5 becomes -10.
  ceiling,

  /// To the nearest whole unit, a tie going away from zero: 10.5 becomes 11,
  /// -10.5 becomes -11.
  halfAwayFromZero,

  /// To the nearest whole unit, a tie going to the even neighbour (banker's
  /// rounding): 10.5 becomes 10, 11.5 becomes 12.
  halfToEven,
}

/// An exact fixed-scale decimal, stored and transported as integer units.
///
/// The coefficient is limited to ±(2^53−1), keeping values lossless in native
/// Dart, JavaScript, JSON transports, and SQL integer columns. Parsing and
/// arithmetic use integer operations; no floating-point conversion occurs.
@immutable
final class BeakDecimal implements Comparable<BeakDecimal> {
  /// Creates [units] × 10^−[scale]. Prefer [parse] for user-entered amounts.
  const BeakDecimal(this.units, {this.scale = 2})
    : assert(scale >= 0 && scale <= 12),
      assert(units >= -maxUnits && units <= maxUnits);

  /// Largest coefficient that every supported runtime represents exactly.
  static const int maxUnits = 9007199254740991;

  static const int _maxDigits = 16;

  /// Signed integer coefficient in the smallest declared unit.
  final int units;

  /// Number of decimal places, from 0 to 12.
  final int scale;

  /// Parses a decimal at [scale], rejecting excess precision and overflow.
  factory BeakDecimal.parse(String source, {int scale = 2}) {
    if (scale < 0 || scale > 12) throw RangeError.range(scale, 0, 12, 'scale');
    final match = RegExp(
      r'^([+-]?)(\d+)(?:\.(\d+))?$',
    ).firstMatch(source.trim());
    if (match == null) {
      throw FormatException('Expected an exact decimal.', source);
    }
    var fraction = match[3] ?? '';
    if (fraction.length > scale) {
      if (fraction.substring(scale).contains(RegExp('[1-9]'))) {
        throw FormatException(
          'Value has more than $scale decimal places.',
          source,
        );
      }
      fraction = fraction.substring(0, scale);
    }
    // Converting a long digit string is quadratic in its length, and a value
    // of more digits than the largest coefficient cannot be one, so it is
    // refused before it is converted.
    final String wholeDigits = match[2]!.replaceFirst(RegExp('^0+(?=.)'), '');
    if (wholeDigits.length + scale > _maxDigits) {
      throw const FormatException(
        'Exact decimal exceeds the safe integer range.',
      );
    }
    final coefficient =
        BigInt.parse('$wholeDigits${fraction.padRight(scale, '0')}') *
        (match[1] == '-' ? -BigInt.one : BigInt.one);
    return _checked(coefficient, scale);
  }

  /// The decimal of [units] whole storage units at [scale], or null when
  /// [units] is not a whole number inside the safe integer range.
  ///
  /// Aggregates arrive as `num`: a sum of stored units is whole, an average
  /// usually is not (use [BeakDecimal.fromRoundedUnits] for that).
  static BeakDecimal? tryFromUnits(num units, {int scale = 2}) {
    if (!units.isFinite ||
        units.abs() > maxUnits ||
        units != units.truncateToDouble()) {
      return null;
    }
    return BeakDecimal(units.toInt(), scale: scale);
  }

  /// The decimal of [units] storage units at [scale], rounded to a whole
  /// number of units as [rounding] says.
  ///
  /// Throws a [FormatException] when [units] is not finite or the rounded
  /// value leaves the safe integer range.
  factory BeakDecimal.fromRoundedUnits(
    num units, {
    required BeakRounding rounding,
    int scale = 2,
  }) {
    if (!units.isFinite) {
      throw FormatException('Expected a finite amount of units.', '$units');
    }
    final int whole = switch (rounding) {
      BeakRounding.floor => units.floor(),
      BeakRounding.ceiling => units.ceil(),
      BeakRounding.halfAwayFromZero => units.round(),
      BeakRounding.halfToEven => _roundHalfToEven(units),
    };
    return _checked(BigInt.from(whole), scale);
  }

  static int _roundHalfToEven(num units) {
    final int lower = units.floor();
    final num fraction = units - lower;
    if (fraction < 0.5) return lower;
    if (fraction > 0.5) return lower + 1;
    return lower.isEven ? lower : lower + 1;
  }

  /// Parses an exact decimal, returning null on syntax, scale, or range errors.
  static BeakDecimal? tryParse(String source, {int scale = 2}) {
    try {
      return BeakDecimal.parse(source, scale: scale);
    } on FormatException {
      return null;
    } on RangeError {
      return null;
    }
  }

  static BeakDecimal _checked(BigInt coefficient, int scale) {
    if (coefficient.abs() > BigInt.from(maxUnits)) {
      throw const FormatException(
        'Exact decimal exceeds the safe integer range.',
      );
    }
    return BeakDecimal(coefficient.toInt(), scale: scale);
  }

  /// Changes scale without rounding; reducing precision must be lossless.
  BeakDecimal rescale(int targetScale) {
    if (targetScale < 0 || targetScale > 12) {
      throw RangeError.range(targetScale, 0, 12, 'targetScale');
    }
    final difference = targetScale - scale;
    if (difference >= 0) {
      return _checked(
        BigInt.from(units) * BigInt.from(10).pow(difference),
        targetScale,
      );
    }
    final divisor = BigInt.from(10).pow(-difference);
    final value = BigInt.from(units);
    if (value.remainder(divisor) != BigInt.zero) {
      throw const FormatException('Rescaling would require rounding.');
    }
    return _checked(value ~/ divisor, targetScale);
  }

  /// Adds two amounts at the greater scale, retaining exact precision.
  BeakDecimal operator +(BeakDecimal other) => _combine(other, false);

  /// Subtracts two amounts at the greater scale, retaining exact precision.
  BeakDecimal operator -(BeakDecimal other) => _combine(other, true);
  BeakDecimal _combine(BeakDecimal other, bool subtract) {
    final target = scale > other.scale ? scale : other.scale;
    final a = BigInt.from(units) * BigInt.from(10).pow(target - scale);
    final b =
        BigInt.from(other.units) * BigInt.from(10).pow(target - other.scale);
    return _checked(subtract ? a - b : a + b, target);
  }

  /// Multiplies by an integral quantity without floating-point arithmetic.
  BeakDecimal operator *(int quantity) =>
      _checked(BigInt.from(units) * BigInt.from(quantity), scale);
  @override
  int compareTo(BeakDecimal other) {
    final target = scale > other.scale ? scale : other.scale;
    return (BigInt.from(units) * BigInt.from(10).pow(target - scale)).compareTo(
      BigInt.from(other.units) * BigInt.from(10).pow(target - other.scale),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BeakDecimal && compareTo(other) == 0;
  @override
  int get hashCode {
    var coefficient = BigInt.from(units);
    var places = scale;
    while (places > 0 &&
        coefficient.remainder(BigInt.from(10)) == BigInt.zero) {
      coefficient ~/= BigInt.from(10);
      places--;
    }
    return Object.hash(coefficient, places);
  }

  @override
  String toString() {
    final digits = units.abs().toString().padLeft(scale + 1, '0');
    final sign = units < 0 ? '-' : '';
    return scale == 0
        ? '$sign$digits'
        : '$sign${digits.substring(0, digits.length - scale)}.${digits.substring(digits.length - scale)}';
  }
}
