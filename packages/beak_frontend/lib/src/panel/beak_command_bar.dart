import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../di/beak_locator.dart';
import '../data/beak_resource_repository.dart';
import '../data/beak_data_changes.dart';
import 'beak_routes.dart';
import '../localization/beak_localizations.dart';
import 'beak_panel_config.dart';

/// Opens the panel command bar — a fuzzy-searchable palette (Ctrl/⌘-K) that
/// jumps to any resource or custom page. Commands are derived from the panel
/// config, so every navigable destination is reachable in two keystrokes with
/// no per-app wiring.
// --8<-- [start:openBeakCommandBar]
OverlayEntry? _commandBarOverlay;

/// Closes the command bar if it is open.
///
/// The panel calls this when it locks, so the palette cannot float above the
/// lock screen. Opening the bar twice closes the first one.
void closeBeakCommandBar() {
  final entry = _commandBarOverlay;
  _commandBarOverlay = null;
  if (entry != null && entry.mounted) entry.remove();
}

/// Opens the command palette over the panel's root overlay.
///
/// Closes a palette that is already open.
void openBeakCommandBar(BuildContext context, BeakPanelConfig config) {
  final GoRouter router = GoRouter.of(context);
  final overlay = Overlay.of(context, rootOverlay: true);
  closeBeakCommandBar();
  late final OverlayEntry entry;
  void close() {
    if (identical(_commandBarOverlay, entry)) _commandBarOverlay = null;
    if (entry.mounted) entry.remove();
  }

  entry = _commandBarOverlay = OverlayEntry(
    builder: (_) => BeakSearchPalette(
      config: config,
      onSelect: (route) {
        close();
        router.go(route);
      },
      onDismiss: close,
    ),
  );
  overlay.insert(entry);
}
// --8<-- [end:openBeakCommandBar]

/// Builds one navigation [OiCommand] per resource and in-nav page, grouped by
/// their sidebar section.
// --8<-- [start:beakNavigationCommands]
List<OiCommand> beakNavigationCommands(
  BeakPanelConfig config,
  void Function(String route) go, {
  BeakLocalizations localizations = BeakLocalizations.english,
}) {
  return [
    for (final resource in config.navigationResources)
      if (resource.isVisible)
        OiCommand(
          id: 'nav:${resource.route}',
          label: resource.effectiveNavigationTitle,
          icon: resource.icon.icon,
          category: resource.navigationGroup ?? localizations.resources,
          keywords: const ['open', 'go to'],
          onExecute: () => go(resource.route),
        ),
    for (final page in config.pages)
      if (page.showInNav && page.isAccessible)
        OiCommand(
          id: 'nav:${page.path}',
          label: page.effectiveNavigationTitle,
          icon: page.icon.icon,
          category: page.navigationGroup ?? localizations.pages,
          keywords: const ['open', 'go to'],
          onExecute: () => go(page.path),
        ),
  ];
}

// --8<-- [end:beakNavigationCommands]

/// Successful matches and independently retryable resource failures.
final class BeakResourceSearchResult {
  /// Collects one search across every visible resource.
  const BeakResourceSearchResult({
    this.items = const [],
    this.errors = const {},
  });

  /// Navigable record matches. Failures never masquerade as records.
  final List<OiSearchResult> items;

  /// Safe resource-label to error mapping; successful resources remain visible.
  final Map<String, BeakException> errors;
}

/// Searches visible resources using generated or explicitly configured paths.
///
/// Text uses substring matching. Numbers and booleans use typed equality;
/// enum names/labels and ISO calendar dates also produce typed predicates.
/// Paths through collections are evaluated by the provider as relation filters.
Future<BeakResourceSearchResult> beakSearchResourcePage(
  BeakPanelConfig config,
  BeakDataSource dataSource,
  String term,
) async {
  final trimmed = term.trim();
  if (trimmed.isEmpty) return const BeakResourceSearchResult();
  final results = await Future.wait([
    for (final resource in config.navigationResources)
      if (resource.isVisible)
        () async {
          final fields = resource.globalSearchSources.isEmpty
              ? [
                  for (final column in resource.model.columns)
                    if (column.searchable) (column, column.key),
                ]
              : [
                  for (final field
                      in resource.globalSearchSources
                          .whereType<BeakScalarField<Object>>())
                    (field.column, field.qualifiedKey),
                ];
          if (fields.isEmpty) return const BeakResourceSearchResult();
          final predicates = <BeakFilter>[];
          for (final (column, key) in fields) {
            if (column.semantic.kind == BeakSemanticKind.password) {
              return BeakResourceSearchResult(
                errors: {
                  resource.effectiveLabel: BeakConfigurationException(
                    'Password column "$key" cannot be searched.',
                  ),
                },
              );
            }
            if (column.semantic.hasCodec && column is! BeakJsonColumn) {
              final Object? parsed = switch (column.semantic.kind) {
                BeakSemanticKind.exactDecimal || BeakSemanticKind.money =>
                  BeakDecimal.tryParse(trimmed, scale: column.semantic.scale),
                BeakSemanticKind.calendarDate => BeakDate.tryParse(trimmed),
                BeakSemanticKind.time => BeakTime.tryParse(trimmed),
                BeakSemanticKind.duration => int.tryParse(trimmed),
                _ => null,
              };
              if (parsed != null) {
                predicates.add(
                  BeakFieldFilter.forKey(
                    key,
                    BeakOperator.eq,
                    column.semantic.encode(parsed),
                  ),
                );
              }
              continue;
            }
            BeakFieldFilter predicate(BeakOperator op, Object? value) =>
                BeakFieldFilter.forKey(key, op, BeakValue.of(value));
            switch (column) {
              case BeakStringColumn() ||
                  BeakTextColumn() ||
                  BeakRichTextColumn():
                predicates.add(predicate(BeakOperator.contains, trimmed));
              case BeakIntColumn():
                if (int.tryParse(trimmed) case final int value) {
                  predicates.add(predicate(BeakOperator.eq, value));
                }
              case BeakDecimalColumn():
                if (double.tryParse(trimmed) case final double value
                    when value.isFinite) {
                  predicates.add(predicate(BeakOperator.eq, value));
                }
              case BeakBoolColumn():
                final value = switch (trimmed.toLowerCase()) {
                  'true' || 'yes' || 'ja' => true,
                  'false' || 'no' || 'nein' => false,
                  _ => null,
                };
                if (value != null) {
                  predicates.add(predicate(BeakOperator.eq, value));
                }
              case BeakEnumColumn<Enum>():
                for (final value in column.values) {
                  if (value.name.toLowerCase().contains(
                        trimmed.toLowerCase(),
                      ) ||
                      column
                          .labelFor(value)
                          .toLowerCase()
                          .contains(trimmed.toLowerCase())) {
                    predicates.add(predicate(BeakOperator.eq, value.name));
                  }
                }
              case BeakDateTimeColumn():
                final date = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)
                    ? DateTime.tryParse(trimmed)
                    : null;
                if (date != null) {
                  predicates.add(
                    BeakAndFilter([
                      predicate(BeakOperator.gte, date),
                      predicate(
                        BeakOperator.lt,
                        DateTime(date.year, date.month, date.day + 1),
                      ),
                    ]),
                  );
                }
              default:
                break;
            }
          }
          if (predicates.isEmpty) return const BeakResourceSearchResult();
          final onlyText = fields.every(
            (field) =>
                !field.$1.semantic.hasCodec &&
                (field.$1 is BeakStringColumn ||
                    field.$1 is BeakTextColumn ||
                    field.$1 is BeakRichTextColumn),
          );
          final result = await BeakResourceRepository(dataSource).query(
            BeakQuerySpec(
              table: resource.model.table,
              search: onlyText
                  ? BeakSearch(trimmed, [for (final field in fields) field.$2])
                  : null,
              filter: onlyText ? null : BeakOrFilter(predicates),
              pagination: const BeakPagination(perPage: 5),
            ),
          );
          if (result case BeakErr(:final error)) {
            return BeakResourceSearchResult(
              errors: {resource.effectiveLabel: error},
            );
          }
          final records = switch (result) {
            BeakOk(:final value) => value.items,
            BeakErr() => const <BeakRecord>[],
          };
          return BeakResourceSearchResult(
            items: [
              for (final record in records)
                if (resource.model.primaryKeyOf(record) case final Object id)
                  OiSearchResult(
                    id: BeakRoutes.show(resource.model.table, id),
                    title:
                        record[resource.model.displayColumnKey]?.raw
                            ?.toString() ??
                        id.toString(),
                    subtitle: resource.effectiveLabel,
                  ),
            ],
          );
        }(),
  ]);
  return BeakResourceSearchResult(
    items: [for (final group in results) ...group.items],
    errors: {for (final group in results) ...group.errors},
  );
}

/// Record-only convenience search; use [beakSearchResourcePage] to show errors.
Future<List<OiSearchResult>> beakSearchResources(
  BeakPanelConfig config,
  BeakDataSource dataSource,
  String term,
) async => (await beakSearchResourcePage(config, dataSource, term)).items;

final class _PaletteEntry {
  const _PaletteEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.semanticLabel,
    this.icon,
  });

  final String id;
  final String title;
  final String category;
  final String semanticLabel;
  final IconData? icon;
}

/// Live panel search with navigation, resource matches and explicit retry.
///
/// The panel uses this in its command dialog. Custom shells may embed it with
/// their own [dataSource] and [onSelect]; mutation refresh is still automatic.
final class BeakSearchPalette extends HookWidget {
  /// Creates the accessible, debounced command and record search.
  const BeakSearchPalette({
    required this.config,
    required this.onSelect,
    required this.onDismiss,
    this.dataSource,
    super.key,
  });

  /// Resources and navigation destinations included in the search.
  final BeakPanelConfig config;

  /// Opens a selected route.
  final ValueChanged<String> onSelect;

  /// Closes the palette, including with Escape.
  final VoidCallback onDismiss;

  /// Optional source for standalone usage; otherwise inherited from the panel.
  final BeakDataSource? dataSource;

  @override
  Widget build(BuildContext context) {
    final strings = BeakLocalizations.of(context);
    final colors = context.colors;
    final spacing = context.spacing;
    final inputFocus = useFocusNode();
    final textController = useTextEditingController();
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) inputFocus.requestFocus();
      });
      return null;
    }, [inputFocus]);
    final source = dataSource ?? beakDependencies(context)<BeakDataSource>();
    final revision = useBeakDataRevision(source);
    final term = useState('');
    final retry = useState(0);
    final selected = useState(0);
    final response = useState(const BeakResourceSearchResult());
    final loading = useState(false);
    useEffect(() {
      var active = true;
      final timer = Timer(const Duration(milliseconds: 200), () async {
        if (!active) return;
        loading.value = term.value.trim().isNotEmpty;
        final result = await beakSearchResourcePage(config, source, term.value);
        if (!active) return;
        response.value = result;
        loading.value = false;
      });
      return () {
        active = false;
        timer.cancel();
      };
    }, [source, config, term.value, revision, retry.value]);

    final resourceIcons = {
      for (final resource in config.navigationResources)
        if (resource.isVisible) resource.effectiveLabel: resource.icon.icon,
    };

    final query = term.value.trim().toLowerCase();
    final items = <_PaletteEntry>[
      for (final command in beakNavigationCommands(
        config,
        (_) {},
        localizations: strings,
      ))
        if (query.isEmpty ||
            command.label.toLowerCase().contains(query) ||
            (command.category?.toLowerCase().contains(query) ?? false) ||
            command.keywords.any((word) => word.toLowerCase().contains(query)))
          _PaletteEntry(
            id: command.id.substring(4),
            title: command.label,
            category: command.category ?? strings.navigate,
            icon: command.icon,
            semanticLabel:
                '${command.label} · ${command.category ?? strings.navigate}',
          ),
      for (final result in response.value.items)
        _PaletteEntry(
          id: result.id,
          title: result.title,
          category: result.subtitle ?? strings.records,
          icon: result.subtitle == null
              ? OiIcons.file
              : resourceIcons[result.subtitle] ?? OiIcons.file,
          semanticLabel:
              '${result.title}${result.subtitle == null ? '' : ' · ${result.subtitle}'}',
        ),
    ];

    final grouped = <String, List<_PaletteEntry>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    final current = items.isEmpty
        ? 0
        : selected.value.clamp(0, items.length - 1);
    void choose() {
      if (items.isNotEmpty) onSelect(items[current].id);
    }

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: strings.commandBar,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDismiss,
              child: ColoredBox(color: colors.overlay),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.35),
            child: Focus(
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                  return KeyEventResult.ignored;
                }
                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  onDismiss();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
                    items.isNotEmpty) {
                  selected.value = (current + 1) % items.length;
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
                    items.isNotEmpty) {
                  selected.value = (current - 1 + items.length) % items.length;
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.enter) {
                  choose();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 560,
                  maxHeight: 480,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: colors.overlay,
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          spacing.md,
                          spacing.md,
                          spacing.md,
                          spacing.sm,
                        ),
                        child: OiRawInput(
                          controller: textController,
                          focusNode: inputFocus,
                          autofocus: true,
                          placeholder: strings.commandBarPlaceholder,
                          textInputAction: TextInputAction.go,
                          onChanged: (value) {
                            selected.value = 0;
                            term.value = value;
                          },
                          onSubmitted: (_) => choose(),
                          leading: Padding(
                            padding: EdgeInsets.only(right: spacing.sm),
                            child: OiIcon.raw(
                              OiIcons.search,
                              size: 18,
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                      ),
                      if (loading.value)
                        Semantics(
                          liveRegion: true,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              spacing.md,
                              0,
                              spacing.md,
                              spacing.sm,
                            ),
                            child: OiLabel.small(
                              strings.loading,
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                      const OiDivider(),
                      Flexible(
                        child: ListView(
                          padding: EdgeInsets.symmetric(vertical: spacing.xs),
                          shrinkWrap: true,
                          children: [
                            for (final entry in response.value.errors.entries)
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: spacing.md,
                                  vertical: spacing.xs,
                                ),
                                child: OiLabel.small(
                                  '${entry.key}: ${strings.errorMessage(entry.value)}',
                                  color: colors.error.base,
                                ),
                              ),
                            if (response.value.errors.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(
                                  left: spacing.md,
                                  bottom: spacing.sm,
                                ),
                                child: OiButton.ghost(
                                  label: strings.retry,
                                  onTap: () => retry.value++,
                                ),
                              ),
                            if (!loading.value &&
                                items.isEmpty &&
                                response.value.errors.isEmpty)
                              Padding(
                                padding: EdgeInsets.all(spacing.lg),
                                child: Center(
                                  child: OiLabel.body(
                                    strings.noRecords,
                                    color: colors.textMuted,
                                  ),
                                ),
                              ),
                            for (final group in grouped.entries) ...[
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  spacing.md,
                                  spacing.sm,
                                  spacing.md,
                                  spacing.xs,
                                ),
                                child: OiLabel.overline(
                                  group.key.toUpperCase(),
                                  color: colors.textMuted,
                                ),
                              ),
                              for (final item in group.value)
                                _PaletteRow(
                                  item: item,
                                  highlighted: items.indexOf(item) == current,
                                  onHover: () =>
                                      selected.value = items.indexOf(item),
                                  onTap: () => onSelect(item.id),
                                ),
                            ],
                          ],
                        ),
                      ),
                      const OiDivider(),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing.md,
                          vertical: spacing.sm,
                        ),
                        child: Row(
                          children: [
                            const OiKbd(keys: ['↑', '↓']),
                            SizedBox(width: spacing.xs),
                            OiLabel.tiny(
                              strings.commandBarSelect,
                              color: colors.textMuted,
                            ),
                            SizedBox(width: spacing.md),
                            const OiKbd(keys: ['↵']),
                            SizedBox(width: spacing.xs),
                            OiLabel.tiny(
                              strings.commandBarOpen,
                              color: colors.textMuted,
                            ),
                            SizedBox(width: spacing.md),
                            const OiKbd(keys: ['esc']),
                            SizedBox(width: spacing.xs),
                            OiLabel.tiny(
                              strings.commandBarClose,
                              color: colors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteRow extends StatelessWidget {
  const _PaletteRow({
    required this.item,
    required this.highlighted,
    required this.onHover,
    required this.onTap,
  });

  final _PaletteEntry item;
  final bool highlighted;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    return MouseRegion(
      onEnter: (_) => onHover(),
      child: Semantics(
        button: true,
        selected: highlighted,
        label: item.semanticLabel,
        child: OiTappable(
          semanticLabel: item.semanticLabel,
          onTap: onTap,
          child: ColoredBox(
            color: highlighted ? colors.surfaceHover : const Color(0x00000000),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.md,
                vertical: spacing.sm,
              ),
              child: Row(
                children: [
                  if (item.icon != null)
                    Padding(
                      padding: EdgeInsets.only(right: spacing.sm),
                      child: OiIcon.raw(
                        item.icon,
                        size: 16,
                        color: highlighted ? colors.text : colors.textMuted,
                      ),
                    ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OiLabel.body(item.title),
                        OiLabel.small(item.category, color: colors.textMuted),
                      ],
                    ),
                  ),
                  if (highlighted)
                    OiIcon.raw(
                      OiIcons.cornerDownLeft,
                      size: 14,
                      color: colors.textMuted,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
