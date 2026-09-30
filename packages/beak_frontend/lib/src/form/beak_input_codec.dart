import 'package:beak_core/beak_core.dart';

import '../formatting/beak_formatting.dart';

/// Parsing boundary for incomplete editor text; never substitutes a valid value.
abstract final class BeakInputCodec {
  /// Parses localized editor text while retaining a useful validation error.
  static ({Object? value, String? error}) parse(
    BeakColumn column,
    String text,
    BeakFormatting formatting,
  ) {
    if (text.isEmpty) return (value: null, error: null);
    try {
      final semantic = column.semantic;
      final Object? value = switch (semantic.kind) {
        BeakSemanticKind.calendarDate => BeakDate.parse(text),
        BeakSemanticKind.time => BeakTime.parse(text),
        BeakSemanticKind.duration => _duration(text),
        BeakSemanticKind.exactDecimal ||
        BeakSemanticKind.money => _decimal(text, semantic.scale, formatting),
        BeakSemanticKind.percentage => switch (formatting.parseNumber(text)) {
          final num number when number.isFinite =>
            number * semantic.percentageScale / 100,
          _ => throw const FormatException('Enter a valid percentage.'),
        },
        BeakSemanticKind.object || BeakSemanticKind.primitiveList =>
          semantic.decode(BeakStringValue(text)),
        _ when column is BeakJsonColumn => BeakJson.decode(text).encode(),
        _ => text,
      };
      return (value: value, error: null);
    } on FormatException catch (error) {
      return (
        value: null,
        error: column is BeakJsonColumn ? 'Must be valid JSON.' : error.message,
      );
    } on ArgumentError {
      return (
        value: null,
        error: 'Enter a value matching the declared field type.',
      );
    }
  }

  static BeakDecimal _decimal(
    String text,
    int scale,
    BeakFormatting formatting,
  ) {
    if (formatting.parseNumber(text) == null) {
      throw const FormatException(
        'Enter a valid amount using the displayed decimal separator.',
      );
    }
    final canonical = text
        .trim()
        .replaceAll(formatting.groupingSeparator, '')
        .replaceAll(formatting.decimalSeparator, '.');
    return BeakDecimal.parse(canonical, scale: scale);
  }

  static Duration _duration(String text) {
    final match = RegExp(
      r'^(-?)(\d+):([0-5]\d)(?::([0-5]\d)(?:\.(\d{1,6}))?)?$',
    ).firstMatch(text);
    if (match == null) {
      throw const FormatException(
        'Use hours:minutes:seconds, for example 2:30:00.',
      );
    }
    final value = Duration(
      hours: int.parse(match[2]!),
      minutes: int.parse(match[3]!),
      seconds: int.parse(match[4] ?? '0'),
      microseconds: int.parse((match[5] ?? '').padRight(6, '0')),
    );
    return match[1] == '-' ? -value : value;
  }

  /// Lossless editing representation independent of display precision.
  static String text(
    BeakColumn column,
    Object? value,
    BeakFormatting formatting,
  ) => switch (value) {
    null => '',
    final BeakDecimal decimal => decimal.toString().replaceAll(
      '.',
      formatting.decimalSeparator,
    ),
    final Duration duration => _trimFraction(duration.toString(), '.'),
    final BeakJson json => json.encode(),
    final List<Object> list => column.semantic.encode(list).raw.toString(),
    final num number when column.semantic.kind == BeakSemanticKind.percentage =>
      _trimFraction(
        formatting.number(
          number * 100 / column.semantic.percentageScale,
          precision: column is BeakDecimalColumn
              ? column.precision
              : formatting.numberPrecision,
          grouping: false,
        ),
        formatting.decimalSeparator,
      ),
    _ => value.toString(),
  };

  static String _trimFraction(String text, String separator) {
    if (!text.contains(separator)) return text;
    final trimmed = text.replaceFirst(RegExp(r'0+$'), '');
    return trimmed.endsWith(separator)
        ? trimmed.substring(0, trimmed.length - separator.length)
        : trimmed;
  }
}
