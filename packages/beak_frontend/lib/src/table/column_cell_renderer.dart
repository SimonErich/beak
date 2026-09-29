import 'dart:convert';
import 'dart:math' as math;

import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

import '../common/hex_color.dart';
import '../form/beak_stored_image.dart';
import '../formatting/beak_formatting.dart';
import '../formatting/beak_field_format.dart';
import '../localization/beak_localizations.dart';

/// Renders a custom-column cell — the escape hatch consumers register per
/// [BeakColumnTag].
// --8<-- [start:BeakCustomCellBuilder]
typedef BeakCustomCellBuilder =
    Widget Function(BuildContext context, BeakColumn column, BeakRecord record);
// --8<-- [end:BeakCustomCellBuilder]

/// The registry of custom cell builders, keyed by column tag.
///
/// Register builders at panel startup; [renderBeakCell] falls back to a
/// muted placeholder for unregistered tags so a missing builder is visible,
/// never a crash. Tags let the same builder back a [BeakCustomColumn]
/// wherever it appears (table or detail).
///
/// ```dart
/// void registerRenderers() {
///   BeakCustomRenderers.register(
///     const BeakColumnTag('sparkline'),
///     (context, column, record) => Sparkline(
///       points: record[column.key]?.raw,
///     ),
///   );
/// }
/// ```
abstract final class BeakCustomRenderers {
  static final Map<BeakColumnTag, BeakCustomCellBuilder> _buildersByTag = {};

  /// Registers [builder] for [tag], replacing any previous one.
  static void register(BeakColumnTag tag, BeakCustomCellBuilder builder) {
    _buildersByTag[tag] = builder;
  }

  /// Removes every registered builder (test isolation).
  static void reset() => _buildersByTag.clear();

  /// The builder for [tag], or `null` when none is registered.
  static BeakCustomCellBuilder? builderFor(BeakColumnTag tag) =>
      _buildersByTag[tag];
}

/// Maps Beak's semantic colors onto obers_ui badge colors.
OiBadgeColor oiBadgeColorFor(BeakColor color) => switch (color) {
  BeakColor.primary => OiBadgeColor.primary,
  BeakColor.secondary => OiBadgeColor.accent,
  BeakColor.success => OiBadgeColor.success,
  BeakColor.warning => OiBadgeColor.warning,
  BeakColor.error => OiBadgeColor.error,
  BeakColor.info => OiBadgeColor.info,
  BeakColor.muted => OiBadgeColor.neutral,
};

/// Renders [column]'s value from [record] by its render intent for
/// [renderContext] — the single place intents become widgets, shared by
/// the table and the detail view.
///
/// [intentOverride] substitutes the column's own intent — relationship
/// fields render through it (relation intents live on relationships, not
/// columns). [onOpenRelation] makes relation links tappable; [now] injects
/// the clock behind relative timestamps. A `null` cell value renders a muted
/// em dash placeholder.
///
/// ```dart
/// OiTableColumn<BeakRecord>(
///   id: column.key,
///   header: column.label,
///   cellBuilder: (context, record, rowIndex) =>
///       renderBeakCell(context, column: column, record: record),
/// )
/// ```
Widget renderBeakCell(
  BuildContext context, {
  required BeakColumn column,
  required BeakRecord record,
  BeakContext renderContext = BeakContext.table,
  BeakRenderIntent? intentOverride,
  VoidCallback? onOpenRelation,
  DateTime Function()? now,
}) {
  final intent = intentOverride ?? column.intentFor(renderContext);
  final formatting = BeakFormatting.maybeOf(context);
  // Custom cells may render eager relations or several fields of the record.
  if (intent == BeakRenderIntent.custom) {
    return _custom(context, column, record);
  }
  final semantic = BeakFormatting.of(context).formatColumn(column, record);
  if (semantic != null) return OiLabel.body(semantic, maxLines: 1);
  final BeakValue? value = record[column.key];
  final Object? raw = value?.raw;
  if (raw == null) {
    return const OiLabel.caption('—');
  }
  return switch (intent) {
    BeakRenderIntent.text => OiLabel.body(raw.toString(), maxLines: 1),
    BeakRenderIntent.number => OiLabel.body(
      _numberText(column, raw, formatting),
      maxLines: 1,
    ),
    BeakRenderIntent.currency => OiLabel.body(
      _currencyText(column, raw, formatting),
      maxLines: 1,
    ),
    BeakRenderIntent.badge => _enumBadge(column, raw),
    BeakRenderIntent.boolean => _booleanBadge(
      column,
      raw,
      BeakLocalizations.of(context),
    ),
    BeakRenderIntent.date => OiLabel.body(
      _dateText(column, raw, formatting),
      maxLines: 1,
    ),
    BeakRenderIntent.relativeDate => OiLabel.body(
      _relativeText(
        raw,
        (now ?? DateTime.now)(),
        BeakLocalizations.of(context),
        formatting,
      ),
      maxLines: 1,
    ),
    BeakRenderIntent.thumbnail => _image(column, raw, sizeInPixels: 40),
    BeakRenderIntent.image => _image(column, raw, sizeInPixels: 160),
    BeakRenderIntent.relationLink => GestureDetector(
      onTap: onOpenRelation,
      child: OiLabel.link(raw.toString(), maxLines: 1),
    ),
    BeakRenderIntent.relationBadges => _relationBadges(raw),
    BeakRenderIntent.richText => OiLabel.body(raw.toString(), maxLines: 2),
    BeakRenderIntent.color => _colorSwatch(raw.toString()),
    BeakRenderIntent.json => OiLabel.code(_jsonText(raw), maxLines: 2),
    BeakRenderIntent.custom => _custom(context, column, record),
  };
}

/// Formats a typed field as plain text with the same policy as field cells.
/// Useful for option labels that combine identity and price without widgets.
String formatBeakField(
  BuildContext context, {
  required BeakScalarField<Object> field,
  required BeakRecord record,
}) {
  final formatting = BeakFormatting.of(context);
  final owner = field.ownerRecord(record);
  if (owner == null) return formatting.emptyValue;
  if (field.column.semantic.kind == BeakSemanticKind.password) {
    return formatting.formatColumn(field.column, owner) ?? '••••••••';
  }
  if (field case BeakFormattedField<Object>(
    :final format,
    :final minorUnits,
    :final scale,
  )) {
    final raw = field.readFrom(record);
    final numeric = raw == null ? null : _asNum(raw);
    return formatting.format(
      minorUnits && numeric != null ? numeric / math.pow(10, scale) : raw,
      format,
    );
  }
  return formatting.formatCell(field.column, owner);
}

/// Renders a typed field path, including display-only formatting overrides.
/// Related fields use the already eager-loaded owner record automatically.
Widget renderBeakField(
  BuildContext context, {
  required BeakScalarField<Object> field,
  required BeakRecord record,
  BeakContext renderContext = BeakContext.table,
}) {
  final owner = field.ownerRecord(record);
  if (owner == null) return const OiLabel.caption('—');
  if (field.column.semantic.kind == BeakSemanticKind.password) {
    return OiLabel.body(
      BeakFormatting.of(context).formatColumn(field.column, owner) ??
          '••••••••',
    );
  }
  if (field case BeakFormattedField<Object>(
    :final format,
    :final minorUnits,
    :final scale,
  )) {
    final formatting = BeakFormatting.of(context);
    final raw = owner[field.key]?.raw;
    final numeric = raw == null ? null : _asNum(raw);
    final value = minorUnits && numeric != null
        ? numeric / math.pow(10, scale)
        : raw;
    return OiLabel.body(formatting.format(value, format), maxLines: 1);
  }
  if ((field.column, owner[field.key]?.raw) case (
    BeakImageColumn(),
    final String key,
  )) {
    return BeakStoredImage(
      column: field.column,
      storageKey: key,
      alt: field.label,
      table: field.path.isEmpty
          ? field.model.table
          : field.path.last.relatedTable,
      sizeInPixels: renderContext == BeakContext.detail ? 160 : 40,
    );
  }
  return renderBeakCell(
    context,
    column: field.column,
    record: owner,
    renderContext: renderContext,
  );
}

/// The formatted display text of [column]'s [raw] value for text-shaped
/// intents (number, currency, date, relative date, plain text) — the same
/// formatting [renderBeakCell] applies, exposed for surfaces that need a
/// string rather than a widget (invoice totals, inbox timestamps, …).
String beakCellText(
  BeakColumn column,
  Object? raw, {
  BeakContext renderContext = BeakContext.detail,
  DateTime Function()? now,
  BeakFormatting? formatting,
  BeakRecord? record,
}) {
  final semantic = (formatting ?? const BeakFormatting()).formatColumn(
    column,
    record ?? BeakRecord(values: {column.key: BeakValue.of(raw)}),
  );
  if (semantic != null) return semantic;
  if (raw == null) {
    return '—';
  }
  return switch (column.intentFor(renderContext)) {
    BeakRenderIntent.number => _numberText(column, raw, formatting),
    BeakRenderIntent.currency => _currencyText(column, raw, formatting),
    BeakRenderIntent.date => _dateText(column, raw, formatting),
    BeakRenderIntent.relativeDate => _relativeText(
      raw,
      (now ?? DateTime.now)(),
      BeakLocalizations.english,
      formatting,
    ),
    _ => raw.toString(),
  };
}

/// Coerces a wire value to a number when possible: Postgres numeric/decimal
/// columns arrive over HTTP as JSON strings, so string decimals must format
/// exactly like native nums.
num? _asNum(Object raw) => switch (raw) {
  final num number => number,
  final String text => num.tryParse(text),
  _ => null,
};

/// Coerces a wire value to a [DateTime] when possible, parsing ISO strings.
DateTime? _asDateTime(Object raw) => switch (raw) {
  final DateTime value => value,
  final String text => DateTime.tryParse(text),
  _ => null,
};

/// Formats a numeric cell: decimal columns honor their configured
/// precision (matching the CSV export), everything else renders raw.
String _numberText(
  BeakColumn column,
  Object raw, [
  BeakFormatting? formatting,
]) => switch ((column, _asNum(raw))) {
  (BeakDecimalColumn(:final precision), final num number) =>
    formatting?.number(number, precision: precision) ??
        number.toStringAsFixed(precision),
  (_, final num number) when formatting != null => formatting.number(number),
  _ => raw.toString(),
};

String _currencyText(
  BeakColumn column,
  Object raw, [
  BeakFormatting? formatting,
]) {
  final (int precision, String prefix, String suffix) = switch (column) {
    BeakDecimalColumn(:final precision, :final prefix, :final suffix) => (
      precision,
      prefix ?? '',
      suffix ?? '',
    ),
    // An integer keeps its own precision: `42 pcs`, never `42.00 pcs`.
    BeakIntColumn(:final prefix, :final suffix) => (
      0,
      prefix ?? '',
      suffix ?? '',
    ),
    _ => (2, '', ''),
  };
  final numeric = _asNum(raw);
  if (formatting != null && numeric != null) {
    if (suffix.isEmpty &&
        (prefix.isEmpty || const ['€', r'$', '£', '¥'].contains(prefix))) {
      return formatting.currency(
        numeric,
        precision: formatting.currencyPrecision ?? precision,
        symbol: prefix.isEmpty ? null : prefix,
      );
    }
    return '$prefix${formatting.number(numeric, precision: precision)}$suffix';
  }
  final String amount = switch (numeric) {
    final num number => number.toStringAsFixed(precision),
    null => raw.toString(),
  };
  return '$prefix$amount$suffix';
}

Widget _enumBadge(BeakColumn column, Object raw) {
  final String name = raw.toString();
  if (column case final BeakEnumColumn<Enum> enumColumn) {
    for (final option in enumColumn.values) {
      if (option.name == name) {
        final BeakColor? color = enumColumn.badgeColorFor(option);
        return OiBadge.soft(
          label: enumColumn.labelFor(option),
          color: color == null ? OiBadgeColor.neutral : oiBadgeColorFor(color),
        );
      }
    }
  }
  return OiBadge.soft(label: name, color: OiBadgeColor.neutral);
}

Widget _booleanBadge(BeakColumn column, Object raw, BeakLocalizations strings) {
  final bool isTrue = raw == true;
  final (String? trueLabel, String? falseLabel) = switch (column) {
    BeakBoolColumn(:final trueLabel, :final falseLabel) => (
      trueLabel,
      falseLabel,
    ),
    _ => (null, null),
  };
  return OiBadge.soft(
    label: isTrue ? (trueLabel ?? strings.yes) : (falseLabel ?? strings.no),
    color: isTrue ? OiBadgeColor.success : OiBadgeColor.neutral,
  );
}

String _dateText(BeakColumn column, Object raw, [BeakFormatting? formatting]) {
  final DateTime? instant = _asDateTime(raw);
  if (instant == null) {
    return raw.toString();
  }
  final BeakDateFormat format = switch (column) {
    BeakDateTimeColumn(:final format) => format,
    _ => BeakDateFormat.standard,
  };
  if (formatting != null) {
    return switch (format) {
      BeakDateFormat.dateOnly => formatting.date(instant),
      BeakDateFormat.timeOnly => formatting.time(instant),
      BeakDateFormat.iso => instant.toIso8601String(),
      BeakDateFormat.standard ||
      BeakDateFormat.relative => formatting.dateTime(instant),
    };
  }
  String two(int part) => part.toString().padLeft(2, '0');
  final String date =
      '${instant.year}-${two(instant.month)}-${two(instant.day)}';
  final String time = '${two(instant.hour)}:${two(instant.minute)}';
  return switch (format) {
    BeakDateFormat.dateOnly => date,
    BeakDateFormat.timeOnly => time,
    BeakDateFormat.iso => instant.toIso8601String(),
    BeakDateFormat.standard || BeakDateFormat.relative => '$date $time',
  };
}

String _relativeText(
  Object rawValue,
  DateTime now, [
  BeakLocalizations strings = BeakLocalizations.english,
  BeakFormatting? formatting,
]) {
  final DateTime? raw = _asDateTime(rawValue);
  if (raw == null) {
    return rawValue.toString();
  }
  final Duration elapsed = now.difference(raw);
  if (elapsed.isNegative) {
    return formatting?.date(raw) ?? _dateTextOf(raw);
  }
  if (elapsed.inMinutes < 1) {
    return strings.justNow;
  }
  if (elapsed.inHours < 1) {
    return strings.minutesAgo(elapsed.inMinutes);
  }
  if (elapsed.inDays < 1) {
    return strings.hoursAgo(elapsed.inHours);
  }
  if (elapsed.inDays < 30) {
    return strings.daysAgo(elapsed.inDays);
  }
  return formatting?.date(raw) ?? _dateTextOf(raw);
}

String _dateTextOf(DateTime instant) {
  String two(int part) => part.toString().padLeft(2, '0');
  return '${instant.year}-${two(instant.month)}-${two(instant.day)}';
}

Widget _image(BeakColumn column, Object raw, {required int sizeInPixels}) =>
    BeakStoredImage(
      column: column,
      storageKey: raw.toString(),
      alt: column.label,
      sizeInPixels: sizeInPixels.toDouble(),
    );

Widget _relationBadges(Object raw) {
  final labels = switch (raw) {
    final List<Object?> items => [
      for (final item in items)
        if (item != null) item.toString(),
    ],
    final Object single => [single.toString()],
  };
  return Wrap(
    spacing: 4,
    runSpacing: 4,
    children: [
      for (final label in labels)
        OiBadge.soft(label: label, color: OiBadgeColor.info),
    ],
  );
}

Widget _colorSwatch(String hex) {
  final Color? parsed = parseBeakHexColor(hex);
  return Wrap(
    spacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (parsed != null)
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: parsed,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      OiLabel.code(hex, maxLines: 1),
    ],
  );
}

String _jsonText(Object raw) {
  if (raw is String) {
    return raw;
  }
  return jsonEncode(raw);
}

// --8<-- [start:custom]
Widget _custom(BuildContext context, BeakColumn column, BeakRecord record) {
  if (column case BeakCustomColumn(:final tag)) {
    final builder = BeakCustomRenderers.builderFor(tag);
    if (builder != null) {
      return builder(context, column, record);
    }
    return OiLabel.caption(BeakLocalizations.of(context).unavailable);
  }
  return OiLabel.caption(BeakLocalizations.of(context).unavailable);
}

// --8<-- [end:custom]
