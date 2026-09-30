import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

import '../formatting/beak_formatting.dart';
import '../localization/beak_localizations.dart';
import 'beak_record_template.dart';

/// A typed activity stream over already loaded relation records.
/// Uses the same locale/time policy as the containing form and table.
class BeakRecordTimeline extends StatelessWidget {
  /// Rendering creates no separate query, editor or submission state.
  const BeakRecordTimeline({
    required this.entries,
    required this.title,
    required this.time,
    this.description,
    this.label = 'Activity',
    this.compact = false,
    this.messages = false,
    this.emphasizeMentions = false,
    this.inlineTime = false,
    this.actor,
    this.messageIdentity,
    this.columns = 1,
    super.key,
  }) : assert(columns > 0);

  /// Loaded, policy-filtered activity records.
  final List<BeakRecord> entries;

  /// Typed activity title.
  final BeakScalarField<String> title;

  /// Typed occurrence timestamp.
  final BeakScalarField<DateTime> time;

  /// Optional secondary activity text.
  final BeakScalarField<String>? description;

  /// Accessible stream label.
  final String label;

  /// Renders flat activity entries instead of the default timeline cards.
  final bool compact;

  /// Renders compact author/time headings above neutral message bubbles.
  final bool messages;

  /// Highlights @Name mentions without changing the persisted message text.
  final bool emphasizeMentions;

  /// Time-first compact rows arranged down each column with a connected rail.
  final bool inlineTime;

  /// Optional actor emphasized before each compact event title.
  final BeakValueBinding<String>? actor;

  /// Typed identity above a message bubble; relation loads belong to the host.
  final BeakRecordTemplate? messageIdentity;

  /// Maximum compact columns, collapsing to fit the available width.
  final int columns;

  @override
  Widget build(BuildContext context) {
    final formatting = BeakFormatting.of(context);
    final sorted = [...entries]
      ..sort((a, b) {
        final left = time.readFrom(a);
        final right = time.readFrom(b);
        return left == null
            ? (right == null ? 0 : 1)
            : right == null
            ? -1
            : right.compareTo(left);
      });
    if (sorted.isEmpty) {
      return OiLabel.caption(BeakLocalizations.of(context).noRecords);
    }
    if (messages) {
      return OiColumn(
        breakpoint: context.breakpoint,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        gap: const OiResponsive<double>(12),
        children: [
          for (final row in sorted)
            OiColumn(
              breakpoint: context.breakpoint,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              gap: const OiResponsive<double>(6),
              children: [
                if (messageIdentity != null)
                  BeakRecordTemplateView(
                    template: messageIdentity!,
                    record: row,
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      OiLabel.caption(
                        title.readFrom(row) ?? formatting.emptyValue,
                      ),
                      OiLabel.caption(
                        '· ${formatting.formatCell(time.column, row)}',
                      ),
                    ],
                  ),
                OiSurface(
                  color: context.colors.surfaceSubtle,
                  borderRadius: context.radius.md,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: _message(
                      context,
                      description?.readFrom(row) ?? formatting.emptyValue,
                    ),
                  ),
                ),
              ],
            ),
        ],
      );
    }
    if (compact && inlineTime) {
      return Semantics(
        label: label,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final count = constraints.maxWidth.isFinite
                ? ((constraints.maxWidth + 24) / 284).floor().clamp(1, columns)
                : columns;
            final perColumn = (sorted.length / count).ceil();
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var column = 0; column < count; column++) ...[
                  if (column > 0) const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (
                          var index = column * perColumn;
                          index < (column + 1) * perColumn &&
                              index < sorted.length;
                          index++
                        )
                          _InlineEvent(
                            time: formatting.format(
                              time.readFrom(sorted[index]),
                              BeakValueFormat.time,
                            ),
                            title:
                                title.readFrom(sorted[index]) ??
                                formatting.emptyValue,
                            actor: actor?.readFrom(sorted[index]),
                            current: index == 0,
                            connected:
                                index + 1 < (column + 1) * perColumn &&
                                index + 1 < sorted.length,
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      );
    }
    if (compact) {
      return Semantics(
        label: label,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final count = constraints.maxWidth.isFinite
                ? ((constraints.maxWidth + 24) / 284).floor().clamp(1, columns)
                : columns;
            return OiGrid(
              breakpoint: context.breakpoint,
              columns: OiResponsive<int>(count),
              gap: const OiResponsive<double>(24),
              rowGap: const OiResponsive<double>(16),
              children: [
                for (final row in sorted)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5, right: 10),
                        child: Icon(
                          OiIcons.circle,
                          size: 10,
                          color: context.colors.primary.base,
                        ),
                      ),
                      Expanded(
                        child: OiColumn(
                          breakpoint: context.breakpoint,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          gap: const OiResponsive<double>(4),
                          children: [
                            OiLabel.bodyStrong(
                              title.readFrom(row) ?? formatting.emptyValue,
                            ),
                            if (description?.readFrom(row)
                                case final String text when text.isNotEmpty)
                              OiLabel.caption(text),
                            OiLabel.caption(
                              formatting.formatCell(time.column, row),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      );
    }
    return OiTimeline(
      label: label,
      showTimestamps: false,
      events: [
        for (final row in sorted)
          OiTimelineEvent(
            // Missing timestamps remain visibly empty; the internal non-rendered
            // timestamp only satisfies the presentation widget's required value.
            timestamp:
                time.readFrom(row) ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            title: title.readFrom(row) ?? formatting.emptyValue,
            description: description?.readFrom(row),
            content: OiLabel.caption(formatting.formatCell(time.column, row)),
          ),
      ],
    );
  }

  Widget _message(BuildContext context, String text) {
    if (!emphasizeMentions) return OiLabel.body(text);
    final spans = <TextSpan>[];
    var end = 0;
    for (final match in RegExp(
      r'@[A-Za-z][\w]*(?: [A-Z][a-z]+)*',
    ).allMatches(text)) {
      spans.add(TextSpan(text: text.substring(end, match.start)));
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            color: context.colors.primary.base,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
      end = match.end;
    }
    spans.add(TextSpan(text: text.substring(end)));
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(children: spans),
          style: context.textTheme.body.copyWith(color: context.colors.text),
        ),
      ),
    );
  }
}

/// A connected event keeps the timestamp column aligned when its title wraps.
class _InlineEvent extends StatelessWidget {
  const _InlineEvent({
    required this.time,
    required this.title,
    required this.current,
    required this.connected,
    this.actor,
  });
  final String time, title;
  final String? actor;
  final bool current, connected;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 8,
          child: Stack(
            children: [
              if (connected)
                Positioned(
                  top: 14,
                  bottom: 0,
                  left: 3.5,
                  child: SizedBox(
                    width: 1,
                    child: ColoredBox(color: context.colors.border),
                  ),
                ),
              Positioned(
                top: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: current
                        ? context.colors.primary.base
                        : context.colors.border,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 36,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: OiLabel.caption(time, color: context.colors.textMuted),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: connected ? 8 : 0),
            child: Text.rich(
              TextSpan(
                children: [
                  if (actor != null && actor!.isNotEmpty)
                    TextSpan(
                      text: '$actor ',
                      style: context.textTheme.bodyStrong,
                    ),
                  TextSpan(text: title),
                ],
              ),
              style: context.textTheme.body.copyWith(
                color: context.colors.text,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
