import 'dart:async';

import '../columns/beak_column.dart';
import '../columns/beak_json.dart';
import '../columns/beak_semantic.dart';
import '../columns/beak_semantic_values.dart';
import '../query/beak_record.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Presentation of a calculated value or relationship summary.
// --8<-- [start:BeakValueFormat]
enum BeakValueFormat {
  /// Uses the value's text representation.
  text,

  /// Uses the panel's number separators and precision.
  number,

  /// Uses the panel's currency and locale.
  currency,

  /// Uses the configured calendar date pattern.
  date,

  /// Uses the configured date and time pattern.
  dateTime,

  /// Uses the configured clock pattern and display zone for an instant or time.
  time,

  /// Formats a fractional value as a percentage, for example 0.2 as 20%.
  percent,
}
// --8<-- [end:BeakValueFormat]

/// One immutable display policy for a panel's forms, tables and summaries.
///
/// Formatting changes presentation only. Dates and numeric values remain typed
/// in drafts and API payloads. A scope can override the policy for a subtree.
class BeakFormatPolicy {
  /// Creates a locale-aware display policy with explicit date patterns.
  // --8<-- [start:BeakFormatPolicy]
  const BeakFormatPolicy({
    this.locale = 'en_US',
    String currency = 'USD',
    this.datePattern = 'yyyy-MM-dd',
    String? dateInputPattern,
    this.dateTimePattern = 'yyyy-MM-dd HH:mm',
    this.timePattern = 'HH:mm',
    this.numberPrecision = 2,
    this.currencyPrecision,
    this.useGrouping = true,
    this.useLocalTime = true,
    this.timeZoneOffsetMinutes,
    this.emptyValue = '—',
  }) : currencyCode = currency,
       dateInputPattern = dateInputPattern ?? datePattern;
  // --8<-- [end:BeakFormatPolicy]

  /// ICU locale used for decimal separators, grouping and currency position.
  final String locale;

  /// ISO 4217 currency code, for example EUR or USD.
  final String currencyCode;

  /// ICU pattern for dates without a time component.
  final String datePattern;

  /// ICU pattern for editable calendar controls and range endpoints.
  /// Defaults to [datePattern]; values remain typed dates, independent of display.
  final String dateInputPattern;

  /// ICU pattern for dates and times.
  final String dateTimePattern;

  /// ICU pattern for times without a calendar date.
  final String timePattern;

  /// Default precision for calculated noninteger numbers.
  final int numberPrecision;

  /// Currency precision; null uses the selected currency's standard precision.
  final int? currencyPrecision;

  /// Whether display numbers use locale-specific thousands separators.
  final bool useGrouping;

  /// Whether absolute timestamps are converted to the device's local timezone.
  final bool useLocalTime;

  /// Explicit fixed UTC offset for portable reports; overrides [useLocalTime].
  /// This is an offset policy, not an IANA timezone with historical DST rules.
  final int? timeZoneOffsetMinutes;

  /// Placeholder used when a displayed field is null.
  final String emptyValue;

  /// Formats a number with the selected locale and optional fixed precision.
  String number(num value, {int? precision, bool? grouping}) {
    final format = NumberFormat.decimalPattern(locale);
    final digits = precision ?? (value is int ? 0 : numberPrecision);
    format.minimumFractionDigits = digits;
    format.maximumFractionDigits = digits;
    if (!(grouping ?? useGrouping)) format.turnOffGrouping();
    return format.format(value);
  }

  /// Formats a monetary amount in major units; cents should be divided by 100.
  String currency(num value, {String? code, String? symbol, int? precision}) {
    final format = symbol == null
        ? NumberFormat.simpleCurrency(
            locale: locale,
            name: code ?? currencyCode,
            decimalDigits: precision ?? currencyPrecision,
          )
        : NumberFormat.currency(
            locale: locale,
            name: code ?? currencyCode,
            symbol: symbol,
            decimalDigits: precision ?? currencyPrecision,
          );
    if (!useGrouping) format.turnOffGrouping();
    return format.format(value);
  }

  /// The localized currency symbol used by monetary inputs.
  String get currencySymbol => NumberFormat.simpleCurrency(
    locale: locale,
    name: currencyCode,
  ).currencySymbol;

  /// Standard number of fractional digits for the selected currency.
  int get moneyPrecision =>
      currencyPrecision ??
      NumberFormat.simpleCurrency(
        locale: locale,
        name: currencyCode,
      ).decimalDigits ??
      2;

  /// Decimal separator accepted by monetary inputs.
  String get decimalSeparator =>
      NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP;

  /// Grouping separator accepted by monetary inputs.
  String get groupingSeparator =>
      NumberFormat.decimalPattern(locale).symbols.GROUP_SEP;

  /// Parses a localized number, rejecting malformed grouping and separators.
  num? parseNumber(String value) {
    final text = value.trim();
    final parts = text.split(decimalSeparator);
    if (parts.length > 2) return null;
    final integer = parts.first;
    final digits = integer.replaceAll(groupingSeparator, '');
    if (!RegExp(r'^-?\d*$').hasMatch(digits)) return null;
    if (parts.length == 2 && !RegExp(r'^\d*$').hasMatch(parts.last)) {
      return null;
    }
    if (integer.contains(groupingSeparator)) {
      final whole = int.tryParse(digits);
      if (whole == null ||
          number(whole, precision: 0, grouping: true) != integer) {
        return null;
      }
    }
    return num.tryParse([digits, if (parts.length == 2) parts.last].join('.'));
  }

  /// Formats a fractional rate, preserving up to [numberPrecision] decimals.
  String percent(num value) {
    final format = NumberFormat.percentPattern(locale)
      ..minimumFractionDigits = 0
      ..maximumFractionDigits = numberPrecision;
    if (!useGrouping) format.turnOffGrouping();
    return format.format(value);
  }

  /// Formats an absolute date using [datePattern].
  String date(DateTime value, {String? pattern}) =>
      _date(value, pattern ?? datePattern);

  /// Formats an absolute date and time using [dateTimePattern].
  String dateTime(DateTime value) => _date(value, dateTimePattern);

  /// Formats an absolute time using [timePattern].
  String time(DateTime value) => _date(value, timePattern);

  static bool _dateSymbolsReady = false;

  /// Installs intl's bundled date data once. It does so synchronously before
  /// returning the already-completed Future, so no request or widget-side
  /// async state is needed.
  void _ensureDateSymbols() {
    if (!_dateSymbolsReady) {
      unawaited(initializeDateFormatting(locale));
      _dateSymbolsReady = true;
    }
  }

  String _date(DateTime value, String pattern) {
    _ensureDateSymbols();
    return DateFormat(pattern, locale).format(switch (timeZoneOffsetMinutes) {
      final int offset => value.toUtc().add(Duration(minutes: offset)),
      null => useLocalTime ? value.toLocal() : value.toUtc(),
    });
  }

  /// Formats a summary or calculated value without hand-written string assembly.
  String format(Object? value, BeakValueFormat format) {
    if (value == null) return emptyValue;
    if (value is BeakDecimal) {
      return switch (format) {
        BeakValueFormat.number => exactDecimal(value),
        BeakValueFormat.currency => exactCurrency(value),
        _ => value.toString(),
      };
    }
    if (value is BeakDate && format == BeakValueFormat.date) {
      return calendarDate(value);
    }
    if (value is BeakTime && format == BeakValueFormat.time) {
      return clockTime(value);
    }
    final numeric = switch (value) {
      final num value => value,
      final String text => num.tryParse(text),
      _ => null,
    };
    final instant = switch (value) {
      final DateTime value => value,
      final String text => DateTime.tryParse(text),
      _ => null,
    };
    return switch (format) {
      BeakValueFormat.number when numeric != null => number(numeric),
      BeakValueFormat.currency when numeric != null => currency(numeric),
      BeakValueFormat.date when instant != null => date(instant),
      BeakValueFormat.dateTime when instant != null => dateTime(instant),
      BeakValueFormat.time when instant != null => time(instant),
      BeakValueFormat.percent when numeric != null => percent(numeric),
      _ => value.toString(),
    };
  }

  /// Formats an exact decimal using localized separators without binary floats.
  String exactDecimal(BeakDecimal value, {bool? grouping}) {
    final text = value.toString();
    final negative = text.startsWith('-');
    final pieces = (negative ? text.substring(1) : text).split('.');
    final integer = number(
      int.parse(pieces.first),
      precision: 0,
      grouping: grouping,
    );
    final symbols = NumberFormat.decimalPattern(locale).symbols;
    final zero = symbols.ZERO_DIGIT.codeUnitAt(0);
    final fraction = pieces.length == 1
        ? ''
        : String.fromCharCodes(
            pieces.last.codeUnits.map((digit) => zero + digit - 48),
          );
    return '${negative ? symbols.MINUS_SIGN : ''}$integer${pieces.length == 1 ? '' : '$decimalSeparator$fraction'}';
  }

  /// Formats exact money while preserving its declared scale and every unit.
  String exactCurrency(BeakDecimal value, {String? code, String? symbol}) {
    final format = symbol == null
        ? NumberFormat.simpleCurrency(
            locale: locale,
            name: code ?? currencyCode,
            decimalDigits: value.scale,
          )
        : NumberFormat.currency(
            locale: locale,
            name: code ?? currencyCode,
            symbol: symbol,
            decimalDigits: value.scale,
          );
    if (!useGrouping) format.turnOffGrouping();
    // Derive sign and currency placement from intl, substitute only the exact
    // number. Passing the coefficient through a double would lose money units.
    final template = format.format(value.units < 0 ? -1 : 1);
    final placeholder = number(1, precision: value.scale, grouping: false);
    final absolute = BeakDecimal(value.units.abs(), scale: value.scale);
    return template.replaceFirst(placeholder, exactDecimal(absolute));
  }

  /// Formats a true calendar date without applying timestamp timezone policy.
  String calendarDate(BeakDate value, {String? pattern}) =>
      _calendar(value.toDateTime(), pattern ?? datePattern);

  /// Formats a wall-clock time without timezone conversion.
  String clockTime(BeakTime value) => _calendar(
    DateTime(
      2000,
      1,
      1,
      value.hour,
      value.minute,
      value.second,
      0,
      value.microsecond,
    ),
    timePattern,
  );

  String _calendar(DateTime value, String pattern) {
    _ensureDateSymbols();
    return DateFormat(pattern, locale).format(value);
  }

  /// Formats elapsed time as hours, minutes, seconds, and exact fractional seconds.
  String duration(Duration value) {
    final micros = value.inMicroseconds.abs();
    final hours = micros ~/ Duration.microsecondsPerHour;
    final minutes = (micros ~/ Duration.microsecondsPerMinute) % 60;
    final seconds = (micros ~/ Duration.microsecondsPerSecond) % 60;
    final fraction = micros % Duration.microsecondsPerSecond;
    return '${value.isNegative ? '-' : ''}${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}${fraction == 0 ? '' : '.${fraction.toString().padLeft(6, '0')}'}';
  }

  /// Formats bytes with explicitly binary units (KiB, MiB, …).
  String fileSize(int bytes) {
    const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB'];
    var index = 0;
    num value = bytes;
    while (value.abs() >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }
    return '${number(value, precision: index == 0 ? 0 : numberPrecision)} ${units[index]}';
  }

  /// Semantic display text, or null when physical column rendering should apply.
  String? formatColumn(BeakColumn column, BeakRecord record) {
    final value = record[column.key];
    if (value?.raw == null) return emptyValue;
    final semantic = column.semantic;
    if (semantic.kind == BeakSemanticKind.none) return null;
    if (semantic.kind == BeakSemanticKind.password) return '••••••••';
    final decoded = semantic.tryDecode(value);
    return switch ((semantic.kind, decoded)) {
      (BeakSemanticKind.calendarDate, final BeakDate date) => calendarDate(
        date,
      ),
      (BeakSemanticKind.time, final BeakTime time) => clockTime(time),
      (BeakSemanticKind.duration, final Duration elapsed) => duration(elapsed),
      (BeakSemanticKind.exactDecimal, final BeakDecimal amount) => exactDecimal(
        amount,
      ),
      (BeakSemanticKind.money, final BeakDecimal amount) => exactCurrency(
        amount,
        code: semantic.currencyFor(record),
      ),
      (BeakSemanticKind.percentage, final num rate) => percent(
        rate / semantic.percentageScale,
      ),
      (BeakSemanticKind.quantity, final num amount) =>
        '${number(amount)}${semantic.unit == null ? '' : ' ${semantic.unit}'}',
      (BeakSemanticKind.fileSize, final int bytes) => fileSize(bytes),
      (BeakSemanticKind.primitiveList, final List<Object> values) =>
        values.map((value) => value.toString()).join(', '),
      (BeakSemanticKind.object, final BeakJsonObject object) => object.encode(),
      _ => decoded?.toString() ?? value!.raw.toString(),
    };
  }

  /// Complete text rendering for export and other non-widget consumers.
  String formatCell(BeakColumn column, BeakRecord record) {
    final semantic = formatColumn(column, record);
    if (semantic != null) return semantic;
    final value = record[column.key];
    return switch (column) {
      BeakDateTimeColumn() => switch (column.readValue(value)) {
        final DateTime instant => switch (column.format) {
          BeakDateFormat.dateOnly => date(instant),
          BeakDateFormat.timeOnly => time(instant),
          BeakDateFormat.iso => instant.toIso8601String(),
          _ => dateTime(instant),
        },
        _ => value?.raw.toString() ?? emptyValue,
      },
      BeakDecimalColumn() => switch (column.readValue(value)) {
        final double amount =>
          column.prefix != null || column.suffix != null
              ? '${column.prefix ?? ''}${number(amount, precision: column.precision)}${column.suffix ?? ''}'
              : number(amount, precision: column.precision),
        _ => value?.raw.toString() ?? emptyValue,
      },
      BeakIntColumn() => switch (column.readValue(value)) {
        final int amount =>
          '${column.prefix ?? ''}${number(amount)}${column.suffix ?? ''}',
        _ => value?.raw.toString() ?? emptyValue,
      },
      BeakBoolColumn() => switch (column.readValue(value)) {
        true => column.trueLabel ?? 'Yes',
        false => column.falseLabel ?? 'No',
        _ => emptyValue,
      },
      BeakEnumColumn<Enum>() => switch (column.readValue(value)) {
        final Enum option => column.labelFor(option),
        _ => value?.raw.toString() ?? emptyValue,
      },
      _ => value?.raw.toString() ?? emptyValue,
    };
  }

  /// JSON policy for portable formatting. Device-local conversion is never sent:
  /// supply [timeZoneOffsetMinutes] explicitly, otherwise exports use UTC.
  Map<String, Object?> toJson() => {
    'locale': locale,
    'currency': currencyCode,
    'datePattern': datePattern,
    'dateInputPattern': dateInputPattern,
    'dateTimePattern': dateTimePattern,
    'timePattern': timePattern,
    'numberPrecision': numberPrecision,
    'currencyPrecision': currencyPrecision,
    'useGrouping': useGrouping,
    'useLocalTime': false,
    'timeZoneOffsetMinutes': timeZoneOffsetMinutes,
    'emptyValue': emptyValue,
  };

  /// Reads an explicitly supplied display policy; malformed fields are rejected.
  factory BeakFormatPolicy.fromJson(Map<String, Object?> json) {
    T option<T extends Object>(String key, T fallback) => switch (json[key]) {
      null => fallback,
      final T value => value,
      _ => throw FormatException('Invalid formatting option "$key".'),
    };
    int? optionalInt(String key) => switch (json[key]) {
      null => null,
      final int value => value,
      _ => throw FormatException('Invalid formatting option "$key".'),
    };
    final locale = option('locale', 'en_US');
    if (Intl.verifiedLocale(
          locale,
          NumberFormat.localeExists,
          onFailure: (_) => null,
        ) ==
        null) {
      throw const FormatException('Unsupported formatting locale.');
    }
    final precision = option('numberPrecision', 2);
    final currencyPrecision = optionalInt('currencyPrecision');
    final offset = optionalInt('timeZoneOffsetMinutes');
    if (precision < 0 ||
        precision > 12 ||
        (currencyPrecision != null &&
            (currencyPrecision < 0 || currencyPrecision > 12)) ||
        (offset != null && offset.abs() > 1440)) {
      throw const FormatException(
        'Formatting precision or UTC offset is out of range.',
      );
    }
    final policy = BeakFormatPolicy(
      locale: locale,
      currency: option('currency', 'USD'),
      datePattern: option('datePattern', 'yyyy-MM-dd'),
      dateInputPattern: option(
        'dateInputPattern',
        option('datePattern', 'yyyy-MM-dd'),
      ),
      dateTimePattern: option('dateTimePattern', 'yyyy-MM-dd HH:mm'),
      timePattern: option('timePattern', 'HH:mm'),
      numberPrecision: precision,
      currencyPrecision: currencyPrecision,
      useGrouping: option('useGrouping', true),
      useLocalTime: false,
      timeZoneOffsetMinutes: offset,
      emptyValue: option('emptyValue', '—'),
    );
    policy._requireFormattablePatterns();
    return policy;
  }

  /// The longest date or time pattern a portable policy accepts: real ones
  /// are a few letters, and a longer one only multiplies the size of every
  /// formatted cell.
  static const int _maxPatternLengthInCharacters = 64;

  /// Formats a sample instant with every date pattern, so a pattern intl
  /// cannot format (it throws `UnsupportedError`) is refused when the policy is read, not when the first
  /// value is formatted (which, in an export, is after the file has started).
  void _requireFormattablePatterns() {
    final patterns = [
      datePattern,
      dateInputPattern,
      dateTimePattern,
      timePattern,
    ];
    if (patterns.any(
      (pattern) => pattern.length > _maxPatternLengthInCharacters,
    )) {
      throw const FormatException(
        'A date or time pattern is longer than $_maxPatternLengthInCharacters characters.',
      );
    }
    final sample = DateTime.utc(2000);
    try {
      for (final pattern in patterns) {
        date(sample, pattern: pattern);
      }
    } on UnsupportedError catch (error) {
      throw FormatException('Invalid date or time pattern: ${error.message}');
    }
  }
}
