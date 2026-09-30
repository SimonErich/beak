import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';

export 'package:beak_core/beak_core.dart'
    show BeakValueFormat, BeakFormatPolicy;

/// A context-scoped display policy shared with API exports.
class BeakFormatting extends BeakFormatPolicy {
  /// Creates a locale-aware display policy with explicit date patterns.
  // --8<-- [start:BeakFormatting]
  const BeakFormatting({
    super.locale,
    super.currency,
    super.datePattern,
    super.dateInputPattern,
    super.dateTimePattern,
    super.timePattern,
    super.numberPrecision,
    super.currencyPrecision,
    super.useGrouping,
    super.useLocalTime,
    super.timeZoneOffsetMinutes,
    super.emptyValue,
  });
  // --8<-- [end:BeakFormatting]

  /// Presents an instant as calendar/clock components in the panel's display zone.
  DateTime toEditorDateTime(DateTime value) => switch (timeZoneOffsetMinutes) {
    final int offset => value.toUtc().add(Duration(minutes: offset)),
    null => useLocalTime ? value.toLocal() : value.toUtc(),
  };

  /// Converts edited wall-clock components back to a canonical UTC instant.
  /// The widget's local/UTC flag is deliberately ignored: its components belong
  /// to the configured panel zone, not necessarily the browser's current zone.
  DateTime fromEditorDateTime(DateTime value) {
    DateTime components({required bool utc}) => utc
        ? DateTime.utc(
            value.year,
            value.month,
            value.day,
            value.hour,
            value.minute,
            value.second,
            value.millisecond,
            value.microsecond,
          )
        : DateTime(
            value.year,
            value.month,
            value.day,
            value.hour,
            value.minute,
            value.second,
            value.millisecond,
            value.microsecond,
          );
    if (timeZoneOffsetMinutes case final int offset) {
      return components(utc: true).subtract(Duration(minutes: offset));
    }
    return components(utc: !useLocalTime).toUtc();
  }

  /// The nearest display policy, or a default policy outside a configured panel.
  static BeakFormatting of(BuildContext context) =>
      maybeOf(context) ?? const BeakFormatting();

  /// The nearest explicit policy; null preserves legacy column formatting.
  static BeakFormatting? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<BeakFormattingScope>()
      ?.formatting;
}

/// Provides one formatting policy to every Beak surface in its subtree.
class BeakFormattingScope extends InheritedWidget {
  /// Overrides the panel's display policy for [child].
  const BeakFormattingScope({
    required this.formatting,
    required super.child,
    super.key,
  });

  /// Display policy shared by descendants.
  final BeakFormatting formatting;

  @override
  bool updateShouldNotify(BeakFormattingScope oldWidget) =>
      formatting != oldWidget.formatting;
}
