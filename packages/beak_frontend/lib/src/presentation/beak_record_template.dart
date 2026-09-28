import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:signals/signals_flutter.dart';

import '../formatting/beak_formatting.dart';
import '../formatting/beak_field_format.dart';
import '../form/beak_form_session.dart';
import '../table/column_cell_renderer.dart';
import 'beak_action_presentation.dart';

/// A typed display value whose dependencies also describe its eager loads.
class BeakValueBinding<T extends Object> {
  /// Reads a generated field using its normal formatting and badges.
  BeakValueBinding.field(
    BeakScalarField<T> field, {
    this.label,
    this.monospace = false,
    this.strong = false,
    this.color,
    this.badge = false,
    this.badgeDot = false,
    this.badgeDotFor,
    this.badgeToken = false,
    this.itemTone,
    this.itemTooltip,
    this.tone,
    this.icon,
    this.iconFor,
    this.maxLines = 1,
    this.textOverflow,
    this.visibleIf,
    this.textStyle,
    this.display,
  }) : field = field,
       dependencies = [field],
       compute = null,
       format = null;

  /// A pure display calculation; persistence remains model behavior's job.
  const BeakValueBinding.computed({
    required this.dependencies,
    required this.compute,
    this.label,
    this.format = BeakValueFormat.text,
    this.monospace = false,
    this.strong = false,
    this.color,
    this.badge = false,
    this.badgeDot = false,
    this.badgeDotFor,
    this.badgeToken = false,
    this.itemTone,
    this.itemTooltip,
    this.tone,
    this.icon,
    this.iconFor,
    this.maxLines = 1,
    this.textOverflow,
    this.visibleIf,
    this.textStyle,
    this.display,
  }) : field = null;

  /// Generated field when this is an ordinary value.
  final BeakScalarField<T>? field;

  /// Every record field used by this binding, including related paths.
  final List<BeakFieldRef<Object>> dependencies;

  /// Optional label preceding the value.
  final String? label;

  /// Pure computation over the current record or existing form draft.
  final T? Function(BeakDraftReader reader)? compute;

  /// Presentation of computed values, without changing the submitted data.
  final BeakValueFormat? format;

  /// Uses the theme's code typography for identifiers.
  final bool monospace;

  /// Emphasizes a text value within the configured hierarchy.
  final bool strong;

  /// Optional semantic text color.
  final BeakColor? color;

  /// Renders the formatted value as a semantic status badge.
  final bool badge;

  /// Adds a decorative status marker inside a [badge] while retaining its label.
  final bool badgeDot;

  /// Optional record-dependent marker visibility, using [dependencies].
  final bool Function(BeakDraftReader reader)? badgeDotFor;

  /// Compact square codes instead of rounded status pills.
  final bool badgeToken;

  /// Per-value badge tone for a scalar or each member of a collection.
  final BeakColor Function(Object value, BeakDraftReader reader)? itemTone;

  /// Optional accessible tooltip explaining an individual code.
  final String? Function(Object value, BeakDraftReader reader)? itemTooltip;

  /// Optional live badge color, evaluated from the declared dependencies.
  final BeakColor? Function(BeakDraftReader reader)? tone;

  /// Optional leading icon, resolved by the active Obers theme.
  /// Rendered inside a [badge], or before the value for ordinary text.
  final IconData? icon;

  /// Optional record-dependent icon, using [dependencies].
  /// When supplied, a null result intentionally omits the icon.
  final IconData? Function(BeakDraftReader reader)? iconFor;

  /// Maximum lines before truncation; null allows the full value to wrap.
  final int? maxLines;

  /// Text overflow policy; omitted values truncate bounded lines and allow
  /// unrestricted values to wrap. Use visible only when neighboring content
  /// leaves room for the full value.
  final TextOverflow? textOverflow;

  /// Hides an optional value without emitting an empty placeholder.
  /// Fields read by this predicate must be included in [dependencies].
  final bool Function(BeakDraftReader reader)? visibleIf;

  /// Optional typography override; omitted properties inherit the active theme.
  final TextStyle? textStyle;

  /// Pure contextual formatting using the panel's locale and timezone policy.
  /// Omitting it retains the model's standard text and export presentation.
  final String Function(T? value, BeakFormatPolicy formatting)? display;

  /// Resolves the binding against a loaded record without creating form state.
  T? readFrom(BeakRecord record) => read(_RecordReader(record));

  /// Resolves presentation visibility without constructing a mutable draft.
  bool visibleFrom(BeakRecord record) =>
      visibleIf?.call(_RecordReader(record)) ?? true;

  /// Resolves the value against a tracked or immutable reader.
  T? read(BeakDraftReader reader) =>
      field == null ? compute!(reader) : reader.read(field!);

  /// Keeps the typed display callback inside its generic binding when a view
  /// stores mixed value types together as [BeakValueBinding<Object>].
  bool get hasDisplay => display != null;

  /// Formats the typed value without narrowing its callback through covariance.
  String? formatDisplay(BeakDraftReader reader, BeakFormatPolicy formatting) =>
      display?.call(read(reader), formatting);
}

/// A coordinated accessible foreground/background pair for identity avatars.
final class BeakAvatarTone {
  /// Colors normally come from the application's semantic theme tokens.
  const BeakAvatarTone({required this.background, required this.foreground});

  /// Initials circle fill.
  final Color background;

  /// Initials/icon foreground.
  final Color foreground;
}

/// Reusable typed identity or summary presentation for a row, card or form.
final class BeakRecordTemplate {
  /// Supplies display values without any fetch or widget controller.
  const BeakRecordTemplate({
    required this.title,
    this.subtitle = const [],
    this.titleMetadata = const [],
    this.badges = const [],
    this.trailing = const [],
    this.avatar = false,
    this.avatarSize = OiAvatarSize.sm,
    this.avatarRadius,
    this.avatarPalette = const [],
    this.avatarTone,
    this.details = const [],
    this.footnote,
    this.icon,
    this.inlineSubtitle = false,
    this.inlineIdentity = false,
    this.inlineBadges = false,
    this.progress,
    this.progressHeight = 4,
    this.progressStriped = false,
    this.iconSize = 40,
    this.identityGap = 8,
    this.textGap = 4,
    this.detailsGap = 8,
    this.detailsSpacing = 16,
    this.identityMinHeight = 0,
    this.footnoteSpacing = 12,
    this.copyableTitle = false,
  });

  /// Compact shorthand for generated scalar fields.
  factory BeakRecordTemplate.fields({
    required BeakScalarField<Object> title,
    List<BeakScalarField<Object>> subtitle = const [],
    List<BeakScalarField<Object>> badges = const [],
    bool avatar = false,
    List<BeakAvatarTone> avatarPalette = const [],
    BeakValueBinding<BeakAvatarTone>? avatarTone,
  }) => BeakRecordTemplate(
    title: BeakValueBinding.field(title),
    subtitle: [for (final field in subtitle) BeakValueBinding.field(field)],
    badges: [for (final field in badges) BeakValueBinding.field(field)],
    avatar: avatar,
    avatarPalette: avatarPalette,
    avatarTone: avatarTone,
  );

  /// Icon surface size; the glyph uses half of this value.
  final double iconSize;

  /// Gap between the identity surface and its text.
  final double identityGap;

  /// Vertical spacing between the title, subtitle and badge lines.
  final double textGap;

  /// Vertical spacing between metadata rows below the identity.
  final double detailsGap;

  /// Space between the identity and its metadata section.
  final double detailsSpacing;

  /// Minimum identity height when a group of cards aligns its metadata rows.
  final double identityMinHeight;

  /// Space above and below the separator preceding the footnote.
  final double footnoteSpacing;

  /// Adds an accessible clipboard action beside the primary title.
  final bool copyableTitle;

  /// Primary value.
  final BeakValueBinding<Object> title;

  /// Secondary values in reading order.
  final List<BeakValueBinding<Object>> subtitle;

  /// Secondary values beside the title; subtitles retain their separate lines.
  final List<BeakValueBinding<Object>> titleMetadata;

  /// Compact field values, including enum badges.
  final List<BeakValueBinding<Object>> badges;

  /// Metadata aligned to the far end of the identity, such as a count or state.
  /// These bindings participate in the same automatic loading as other values.
  final List<BeakValueBinding<Object>> trailing;

  /// Displays initials derived from the primary label.
  final bool avatar;

  /// Initials size, shared with the UI kit's identity scale.
  final OiAvatarSize avatarSize;

  /// Rounded initials surface for organizations; null preserves circular avatars.
  final BorderRadius? avatarRadius;

  /// Stable identity colors, selected deterministically from the title.
  final List<BeakAvatarTone> avatarPalette;

  /// Optional record-dependent identity colors. Dependencies load automatically.
  /// A null value falls back to the deterministic [avatarPalette].
  final BeakValueBinding<BeakAvatarTone>? avatarTone;

  /// Optional themed identity icon, with typed dependencies like any value.
  /// When supplied it replaces initials with a soft, square icon surface.
  final BeakValueBinding<IconData>? icon;

  /// Keeps subtitles on one wrapping line unless a containing view overrides it.
  final bool inlineSubtitle;

  /// Keeps the title and secondary identity text on one wrapping line.
  final bool inlineIdentity;

  /// Places badges beside the title, useful for compact review rows.
  final bool inlineBadges;

  /// Metadata rows below the identity, with optional icons and formatting.
  final List<BeakValueBinding<Object>> details;

  /// Optional separated contextual note below the metadata.
  final BeakValueBinding<Object>? footnote;

  /// Optional fraction (0–1) rendered as a compact capacity/progress bar.
  final BeakValueBinding<num>? progress;

  /// Capacity-track geometry, independent of record data.
  final double progressHeight;

  /// Hatches remaining capacity while keeping the same accessible value.
  final bool progressStriped;

  /// Dependencies used to load this presentation in one query.
  List<BeakFieldRef<Object>> get fields => [
    ...title.dependencies,
    for (final value in [
      ...titleMetadata,
      ...subtitle,
      ...badges,
      ...trailing,
      ...details,
    ])
      ...value.dependencies,
    if (footnote case final note?) ...note.dependencies,
    if (icon case final icon?) ...icon.dependencies,
    if (avatarTone case final tone?) ...tone.dependencies,
    if (progress case final progress?) ...progress.dependencies,
  ];
}

/// A region of a record template, for composed identity and metadata surfaces.
enum BeakRecordTemplatePart {
  /// Identity followed by metadata and a contextual note.
  all,

  /// Title, avatar, subtitle and badges only.
  identity,

  /// Metadata and contextual note without the identity.
  details,
}

/// One presentation column, optionally sortable by an explicit typed field.
final class BeakTableColumn {
  /// A composite column whose field loads are automatically inferred.
  const BeakTableColumn({
    required this.key,
    required this.label,
    required BeakRecordTemplate this.template,
    this.sortBy,
    this.width,
    this.minWidth = 160,
    this.textAlign = TextAlign.start,
    this.cellPadding,
  }) : actionSelector = null,
       actionChoices = const {},
       fallbackAction = null;

  /// Selects an existing action from typed record data without owning execution.
  /// Unavailable actions remain absent; presentation never grants permission.
  const BeakTableColumn.action({
    required this.key,
    required this.label,
    required BeakValueBinding<String> selector,
    required Map<String, BeakActionPresentation> choices,
    BeakActionPresentation? fallback,
    this.width,
    this.minWidth = 160,
    this.textAlign = TextAlign.start,
    this.cellPadding,
  }) : actionSelector = selector,
       actionChoices = choices,
       fallbackAction = fallback,
       template = null,
       sortBy = null;

  /// Optional record-dependent action selector.
  final BeakValueBinding<String>? actionSelector;

  /// Maps selector values to existing resource/model action identities.
  final Map<String, BeakActionPresentation> actionChoices;

  /// Optional action when the selector has no configured match.
  final BeakActionPresentation? fallbackAction;

  /// All fields needed to render either a template or an action selector.
  List<BeakFieldRef<Object>> get fields => [
    ...?template?.fields,
    ...?actionSelector?.dependencies,
  ];

  /// Ordinary scalar shorthand with model label and formatting.
  factory BeakTableColumn.field(
    BeakScalarField<Object> field, {
    double? width,
    double minWidth = 160,
    TextAlign textAlign = TextAlign.start,
    EdgeInsetsGeometry? cellPadding,
  }) => BeakTableColumn(
    key: field.qualifiedKey,
    label: field.label,
    template: BeakRecordTemplate.fields(title: field),
    sortBy: field,
    width: width,
    minWidth: minWidth,
    textAlign: textAlign,
    cellPadding: cellPadding,
  );

  /// Stable presentation identity, not a database column name.
  final String key;

  /// Column heading.
  final String label;

  /// Record presentation used for each cell.
  final BeakRecordTemplate? template;

  /// Optional scalar ordering; related ordering is not inferred.
  final BeakScalarField<Object>? sortBy;

  /// Initial width in logical pixels.
  final double? width;

  /// Readable width before a flexible column scrolls on a narrow viewport.
  /// Explicit [width] remains authoritative.
  final double minWidth;

  /// Alignment shared by the heading and rendered cells, for example numeric ends.
  final TextAlign textAlign;

  /// Optional insets shared by the column heading and cells.
  /// Null retains the table theme's padding.
  final EdgeInsetsGeometry? cellPadding;
}

/// Renders the same definition from stored data or the active form draft.
class BeakRecordTemplateView extends StatelessWidget {
  /// Exactly one data binding must be supplied; neither owns persistence.
  const BeakRecordTemplateView({
    required this.template,
    this.record,
    this.draft,
    this.inlineSubtitle,
    this.titleVariant,
    this.subtitleVariant,
    this.inlineBadges,
    this.metadataTrailing,
    this.metadataLeading,
    this.detailsLeading,
    this.titleTrailing,
    this.highlightQuery,
    this.avatarTone,
    this.part = BeakRecordTemplatePart.all,
    super.key,
  }) : assert((record == null) != (draft == null));

  /// Keeps secondary values on a wrapping line for compact choice lists.
  final bool? inlineSubtitle;

  /// Optional contextual title typography, for example a record page heading.
  final OiLabelVariant? titleVariant;

  /// Contextual secondary typography; ordinary identities use caption text.
  final OiLabelVariant? subtitleVariant;

  /// Keeps status badges beside the title on a wrapping line.
  final bool? inlineBadges;

  /// Optional contextual action beside inline secondary values.
  /// Form/catalog hosts keep ownership of its state and permissions.
  final Widget? metadataTrailing;

  /// Contextual controls before inline secondary values, such as a variant
  /// selector. Form/catalog hosts retain state and permission ownership.
  final Widget? metadataLeading;

  /// Contextual indicator beside the first detail, owned by the selection host.
  final Widget? detailsLeading;

  /// Contextual annotation beside the title, owned by the containing screen.
  final Widget? titleTrailing;

  /// Search terms highlighted by the shared typography primitive.
  final String? highlightQuery;

  /// Contextual selection colors supplied by the containing themed control.
  final BeakAvatarTone? avatarTone;

  /// Selects a region when a containing component arranges identity and details.
  final BeakRecordTemplatePart part;

  /// Display definition.
  final BeakRecordTemplate template;

  /// Authorized, eagerly loaded row.
  final BeakRecord? record;

  /// Existing draft, observed directly without another controller.
  final BeakDraftRecord? draft;

  @override
  Widget build(BuildContext context) => Watch.builder(
    builder: (context) {
      final row = draft?.snapshot ?? record!;
      final reader = draft ?? _RecordReader(row);
      final inlineSubtitle = this.inlineSubtitle ?? template.inlineSubtitle;
      final inlineBadges = this.inlineBadges ?? template.inlineBadges;
      final label = template.title.read(reader)?.toString() ?? '';
      bool visible(BeakValueBinding<Object> binding) =>
          binding.visibleIf?.call(reader) ?? true;
      bool hasContent(BeakValueBinding<Object> binding) {
        if (!visible(binding)) return false;
        bool present(Object? value) => switch (value) {
          null => false,
          final String value => value.trim().isNotEmpty,
          final Iterable<Object?> values => values.any(present),
          _ => true,
        };
        return present(binding.read(reader));
      }

      Widget value(BeakValueBinding<Object> binding, {bool secondary = false}) {
        final field = binding.field;
        final icon = binding.iconFor == null
            ? binding.icon
            : binding.iconFor!(reader);
        final formatting = BeakFormatting.of(context);
        Color? semanticColor() =>
            switch (binding.tone?.call(reader) ?? binding.color) {
              BeakColor.primary => context.colors.primary.base,
              BeakColor.secondary => context.colors.accent.base,
              BeakColor.success => context.colors.success.base,
              BeakColor.warning => context.colors.warning.base,
              BeakColor.error => context.colors.error.base,
              BeakColor.info => context.colors.info.base,
              BeakColor.muted => context.colors.textMuted,
              null => secondary ? context.colors.textMuted : null,
            };
        String text() {
          if (binding.hasDisplay) {
            return binding.formatDisplay(reader, formatting)!;
          }
          if (field == null) {
            return formatting.format(binding.read(reader), binding.format!);
          }
          if (field case BeakFormattedField<Object>(
            :final format,
            :final minorUnits,
            :final scale,
          )) {
            final raw = binding.read(reader);
            return formatting.format(
              minorUnits && raw is int ? BeakDecimal(raw, scale: scale) : raw,
              format,
            );
          }
          final owner = field.ownerRecord(row);
          return owner == null
              ? formatting.emptyValue
              : formatting.formatCell(field.column, owner);
        }

        final heading = identical(binding, template.title)
            ? titleVariant
            : null;
        final styled =
            heading != null ||
            field == null ||
            binding.monospace ||
            binding.strong ||
            binding.color != null ||
            binding.tone != null ||
            icon != null ||
            binding.maxLines != 1 ||
            binding.textOverflow != null ||
            binding.textStyle != null ||
            binding.hasDisplay ||
            highlightQuery?.isNotEmpty == true ||
            secondary;
        final badgeColor =
            binding.tone?.call(reader) ?? binding.color ?? BeakColor.muted;
        Widget badge(String label, Object item) {
          final color = switch (binding.itemTone?.call(item, reader) ??
              badgeColor) {
            BeakColor.primary => OiBadgeColor.primary,
            BeakColor.secondary => OiBadgeColor.accent,
            BeakColor.success => OiBadgeColor.success,
            BeakColor.warning => OiBadgeColor.warning,
            BeakColor.error => OiBadgeColor.error,
            BeakColor.info => OiBadgeColor.info,
            BeakColor.muted => OiBadgeColor.neutral,
          };
          final badge = binding.badgeToken
              ? OiBadge.token(label: label, color: color)
              : OiBadge.soft(
                  label: label,
                  color: color,
                  showDot:
                      binding.badgeDotFor?.call(reader) ?? binding.badgeDot,
                  icon: icon,
                );
          final tooltip = binding.itemTooltip?.call(item, reader);
          return tooltip == null
              ? badge
              : OiTooltip(label: tooltip, message: tooltip, child: badge);
        }

        final raw = binding.badge ? binding.read(reader) : null;
        final content = binding.badge
            ? raw is Iterable<Object?>
                  ? Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final item in raw.whereType<Object>())
                          badge(
                            formatting.format(
                              item,
                              binding.format ?? BeakValueFormat.text,
                            ),
                            item,
                          ),
                      ],
                    )
                  : badge(text(), raw ?? '')
            : styled
            ? OiLabel.variant(
                text(),
                highlightQuery: highlightQuery,
                maxLines: binding.maxLines,
                overflow:
                    binding.textOverflow ??
                    (binding.maxLines == null
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis),
                variant:
                    heading ??
                    (binding.monospace
                        ? OiLabelVariant.code
                        : secondary
                        ? subtitleVariant ?? OiLabelVariant.caption
                        : binding.strong
                        ? OiLabelVariant.bodyStrong
                        : OiLabelVariant.body),
                color: semanticColor(),
                style: heading != null && binding.monospace
                    ? TextStyle(
                        fontFamily: context.textTheme.code.fontFamily,
                        fontFamilyFallback:
                            context.textTheme.code.fontFamilyFallback,
                        fontVariations: const [],
                      ).merge(binding.textStyle)
                    : binding.textStyle,
              )
            : renderBeakField(context, field: field, record: row);
        final labeled = binding.label == null
            ? content
            : Wrap(
                spacing: 4,
                children: [OiLabel.caption(binding.label!), content],
              );
        return icon == null || binding.badge
            ? labeled
            : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OiIcon.raw(icon, size: 16, color: context.colors.textMuted),
                  const SizedBox(width: 8),
                  Flexible(child: labeled),
                ],
              );
      }

      final subtitles = template.subtitle.where(hasContent).toList();
      final badges = template.badges.where(hasContent).toList();
      Widget primaryTitleValue() => template.copyableTitle
          ? Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                value(template.title),
                OiCopyButton(value: label, semanticLabel: 'Copy $label'),
              ],
            )
          : value(template.title);
      final titleMetadata = template.titleMetadata.where(hasContent).toList();
      Widget primaryTitle() => titleMetadata.isEmpty
          ? primaryTitleValue()
          : Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                primaryTitleValue(),
                for (final binding in titleMetadata) ...[
                  OiLabel.body('·', color: context.colors.textMuted),
                  value(binding, secondary: true),
                ],
              ],
            );
      final text = OiColumn(
        breakpoint: context.breakpoint,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        gap: OiResponsive<double>(template.textGap),
        children: [
          if (template.inlineIdentity)
            Wrap(
              spacing: 8,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                primaryTitle(),
                for (var index = 0; index < subtitles.length; index++) ...[
                  if (index > 0)
                    OiLabel.caption('·', color: context.colors.textMuted),
                  value(subtitles[index], secondary: true),
                ],
                for (final binding in badges) value(binding),
                ?titleTrailing,
              ],
            )
          else if (inlineBadges || titleTrailing != null)
            Wrap(
              spacing: 10,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                primaryTitle(),
                if (inlineBadges)
                  for (final binding in badges) value(binding),
                ?titleTrailing,
              ],
            )
          else
            primaryTitle(),
          if (!template.inlineIdentity &&
              inlineSubtitle &&
              (subtitles.isNotEmpty ||
                  metadataLeading != null ||
                  metadataTrailing != null))
            Wrap(
              spacing: 6,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ?metadataLeading,
                for (var i = 0; i < subtitles.length; i++) ...[
                  if (i > 0 && !subtitles[i].badge && !subtitles[i - 1].badge)
                    OiLabel.variant(
                      '·',
                      variant: subtitleVariant ?? OiLabelVariant.caption,
                      color: context.colors.textMuted,
                    ),
                  value(subtitles[i], secondary: true),
                ],
                ?metadataTrailing,
              ],
            )
          else if (!template.inlineIdentity)
            for (final binding in subtitles) value(binding, secondary: true),
          if (!template.inlineIdentity && !inlineBadges && badges.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [for (final binding in badges) value(binding)],
            ),
        ],
      );
      final tones = template.avatarPalette;
      final tone =
          avatarTone ??
          template.avatarTone?.read(reader) ??
          (tones.isEmpty
              ? null
              : tones[label.runes.fold<int>(
                      0,
                      (hash, code) => ((hash * 31) + code) & 0x7fffffff,
                    ) %
                    tones.length]);
      final identityIcon = template.icon?.read(reader);
      final leadingIdentity = template.avatar || identityIcon != null
          ? OiRow(
              breakpoint: context.breakpoint,
              gap: OiResponsive<double>(template.identityGap),
              children: [
                if (identityIcon != null)
                  Container(
                    width: template.iconSize,
                    height: template.iconSize,
                    decoration: BoxDecoration(
                      color: tone?.background ?? context.colors.surfaceSubtle,
                      borderRadius: template.avatarRadius ?? context.radius.md,
                    ),
                    child: Center(
                      child: OiIcon.decorative(
                        icon: identityIcon,
                        size: template.iconSize / 2,
                        color: tone?.foreground ?? context.colors.textMuted,
                      ),
                    ),
                  )
                else
                  ExcludeSemantics(
                    child: OiAvatar(
                      semanticLabel: label,
                      backgroundColor: tone?.background,
                      foregroundColor: tone?.foreground,
                      initials: label
                          .split(RegExp(r'\s+'))
                          .where((word) => word.isNotEmpty)
                          .take(2)
                          .map((word) => word[0])
                          .join()
                          .toUpperCase(),
                      size: template.avatarSize,
                      borderRadius: template.avatarRadius,
                    ),
                  ),
                Flexible(child: text),
              ],
            )
          : text;
      final trailing = template.trailing.where(hasContent).toList();
      final naturalIdentity = trailing.isEmpty
          ? leadingIdentity
          : Row(
              children: [
                Expanded(child: leadingIdentity),
                const SizedBox(width: 12),
                for (var i = 0; i < trailing.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  value(trailing[i]),
                ],
              ],
            );
      final identity = template.identityMinHeight == 0
          ? naturalIdentity
          : ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: template.identityMinHeight,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                heightFactor: 1,
                child: naturalIdentity,
              ),
            );
      final details = template.details.where(visible).toList();
      final note = template.footnote;
      final progress = template.progress != null && visible(template.progress!)
          ? template.progress!.read(reader)
          : null;
      if (part == BeakRecordTemplatePart.identity) return identity;
      if (details.isEmpty &&
          (note == null || !visible(note)) &&
          progress == null) {
        return part == BeakRecordTemplatePart.details
            ? const SizedBox.shrink()
            : identity;
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (part != BeakRecordTemplatePart.details) ...[
            identity,
            if (details.isNotEmpty && progress == null)
              SizedBox(height: template.detailsSpacing),
          ],
          if (progress != null)
            Padding(
              padding: EdgeInsets.only(top: 8, bottom: details.isEmpty ? 0 : 8),
              child: Semantics(
                label: '$label progress',
                value: '${(progress.toDouble().clamp(0, 1) * 100).round()}%',
                child: OiCapacityIndicator(
                  label: '$label progress',
                  value: progress.toDouble().clamp(0, 1),
                  max: 1,
                  height: template.progressHeight,
                  stripedRemainder: template.progressStriped,
                  showLabel: false,
                  showValue: false,
                  warningColor: context.colors.primary.base,
                ),
              ),
            ),
          for (var i = 0; i < details.length; i++) ...[
            if (i > 0) SizedBox(height: template.detailsGap),
            if (i == 0 && detailsLeading != null)
              Row(
                children: [
                  detailsLeading!,
                  const SizedBox(width: 4),
                  Expanded(child: value(details[i])),
                ],
              )
            else
              value(details[i]),
          ],
          if (note != null && visible(note)) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: template.footnoteSpacing),
              child: SizedBox(
                height: 1,
                width: double.infinity,
                child: ColoredBox(color: context.colors.borderSubtle),
              ),
            ),
            value(note, secondary: true),
          ],
        ],
      );
    },
  );
}

final class _RecordReader implements BeakDraftReader {
  const _RecordReader(this.record);
  final BeakRecord record;
  @override
  T? read<T extends Object>(BeakFieldRef<T> field) => field.readFrom(record);
}
