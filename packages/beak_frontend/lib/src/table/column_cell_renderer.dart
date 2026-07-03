import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

import '../common/hex_color.dart';

/// Renders a custom-column cell — the escape hatch consumers register per
/// [BeakColumnTag].
typedef BeakCustomCellBuilder =
    Widget Function(BuildContext context, BeakColumn column, BeakRecord record);

/// The registry of custom cell builders, keyed by column tag.
///
/// Register builders at panel startup; [renderBeakCell] falls back to a
/// muted placeholder for unregistered tags so a missing builder is visible,
/// never a crash.
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
/// the table (Phase 12) and the detail view (Phase 13).
///
/// [intentOverride] substitutes the column's own intent — relationship
/// fields render through it (relation intents live on relationships, not
/// columns). [onOpenRelation] makes relation links tappable; [now] injects
/// the clock behind relative timestamps.
Widget renderBeakCell(
  BuildContext context, {
  required BeakColumn column,
  required BeakRecord record,
  BeakContext renderContext = BeakContext.table,
  BeakRenderIntent? intentOverride,
  VoidCallback? onOpenRelation,
  DateTime Function()? now,
}) {
  final BeakValue? value = record[column.key];
  final Object? raw = value?.raw;
  if (raw == null) {
    return const OiLabel.caption('—');
  }
  return switch (intentOverride ?? column.intentFor(renderContext)) {
    BeakRenderIntent.text => OiLabel.body(raw.toString(), maxLines: 1),
    BeakRenderIntent.number => OiLabel.body(raw.toString(), maxLines: 1),
    BeakRenderIntent.currency => OiLabel.body(
      _currencyText(column, raw),
      maxLines: 1,
    ),
    BeakRenderIntent.badge => _enumBadge(column, raw),
    BeakRenderIntent.boolean => _booleanBadge(column, raw),
    BeakRenderIntent.date => OiLabel.body(_dateText(column, raw), maxLines: 1),
    BeakRenderIntent.relativeDate => OiLabel.body(
      _relativeText(raw, (now ?? DateTime.now)()),
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

String _currencyText(BeakColumn column, Object raw) {
  final (int precision, String prefix, String suffix) = switch (column) {
    BeakDecimalColumn(:final precision, :final prefix, :final suffix) => (
      precision,
      prefix ?? '',
      suffix ?? '',
    ),
    _ => (2, '', ''),
  };
  final String amount = switch (raw) {
    final num number => number.toStringAsFixed(precision),
    final Object other => other.toString(),
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

Widget _booleanBadge(BeakColumn column, Object raw) {
  final bool isTrue = raw == true;
  final (String? trueLabel, String? falseLabel) = switch (column) {
    BeakBoolColumn(:final trueLabel, :final falseLabel) => (
      trueLabel,
      falseLabel,
    ),
    _ => (null, null),
  };
  return OiBadge.soft(
    label: isTrue ? (trueLabel ?? 'Yes') : (falseLabel ?? 'No'),
    color: isTrue ? OiBadgeColor.success : OiBadgeColor.neutral,
  );
}

String _dateText(BeakColumn column, Object raw) {
  if (raw is! DateTime) {
    return raw.toString();
  }
  final BeakDateFormat format = switch (column) {
    BeakDateTimeColumn(:final format) => format,
    _ => BeakDateFormat.standard,
  };
  String two(int part) => part.toString().padLeft(2, '0');
  final String date = '${raw.year}-${two(raw.month)}-${two(raw.day)}';
  final String time = '${two(raw.hour)}:${two(raw.minute)}';
  return switch (format) {
    BeakDateFormat.dateOnly => date,
    BeakDateFormat.timeOnly => time,
    BeakDateFormat.iso => raw.toIso8601String(),
    BeakDateFormat.standard || BeakDateFormat.relative => '$date $time',
  };
}

String _relativeText(Object raw, DateTime now) {
  if (raw is! DateTime) {
    return raw.toString();
  }
  final Duration elapsed = now.difference(raw);
  if (elapsed.isNegative) {
    return _dateTextOf(raw);
  }
  if (elapsed.inMinutes < 1) {
    return 'just now';
  }
  if (elapsed.inHours < 1) {
    return '${elapsed.inMinutes}m ago';
  }
  if (elapsed.inDays < 1) {
    return '${elapsed.inHours}h ago';
  }
  if (elapsed.inDays < 30) {
    return '${elapsed.inDays}d ago';
  }
  return _dateTextOf(raw);
}

String _dateTextOf(DateTime instant) {
  String two(int part) => part.toString().padLeft(2, '0');
  return '${instant.year}-${two(instant.month)}-${two(instant.day)}';
}

Widget _image(BeakColumn column, Object raw, {required int sizeInPixels}) =>
    OiImage(
      src: raw.toString(),
      alt: column.label,
      width: sizeInPixels.toDouble(),
      height: sizeInPixels.toDouble(),
      fit: BoxFit.cover,
      errorWidget: const OiIcon.decorative(icon: OiIcons.image),
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

Widget _custom(BuildContext context, BeakColumn column, BeakRecord record) {
  if (column case BeakCustomColumn(:final tag)) {
    final builder = BeakCustomRenderers.builderFor(tag);
    if (builder != null) {
      return builder(context, column, record);
    }
    return OiLabel.caption('No renderer for "${tag.value}"');
  }
  return const OiLabel.caption('Unsupported custom cell');
}
