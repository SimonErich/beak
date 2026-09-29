import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../overlays/beak_overlays.dart';
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
void openBeakCommandBar(BuildContext context, BeakPanelConfig config) {
  final GoRouter router = GoRouter.of(context);
  final strings = BeakLocalizations.of(context);
  void go(String route) => router.go(route);
  BeakOverlays(context).dialog<void>(
    title: strings.goTo,
    builder: (close) => SizedBox(
      width: 640,
      height: 440,
      child: BeakSearchPalette(
        config: config,
        onSelect: (route) {
          close();
          go(route);
        },
        onDismiss: () => close(),
      ),
    ),
  );
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
      if (page.showInNav)
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
    final inputFocus = useFocusNode();
    useEffect(() {
      // The dialog establishes its focus trap after mounting. Request the
      // input afterwards so immediate typing reaches the search field.
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
    final navigation = [
      for (final command in beakNavigationCommands(
        config,
        (_) {},
        localizations: strings,
      ))
        if (term.value.isEmpty ||
            command.label.toLowerCase().contains(term.value.toLowerCase()))
          OiSearchResult(
            id: command.id.substring(4),
            title: command.label,
            subtitle: strings.navigate,
          ),
    ];
    final items = [...navigation, ...response.value.items];
    final current = items.isEmpty
        ? 0
        : selected.value.clamp(0, items.length - 1);
    void choose() {
      if (items.isNotEmpty) onSelect(items[current].id);
    }

    return Focus(
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
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
        return KeyEventResult.ignored;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OiTextInput(
            label: strings.search,
            autofocus: true,
            focusNode: inputFocus,
            onChanged: (value) {
              selected.value = 0;
              term.value = value;
            },
            onSubmitted: (_) => choose(),
          ),
          const SizedBox(height: 12),
          if (loading.value)
            Semantics(liveRegion: true, child: OiLabel.body(strings.loading)),
          Expanded(
            child: ListView(
              children: [
                for (final entry in response.value.errors.entries)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OiLabel.body(
                        '${entry.key}: ${entry.value.message}',
                      ),
                    ),
                  ),
                if (response.value.errors.isNotEmpty)
                  OiButton.ghost(
                    label: strings.retry,
                    onTap: () => retry.value++,
                  ),
                for (var index = 0; index < items.length; index++)
                  Semantics(
                    selected: index == current,
                    child: OiButton.ghost(
                      label:
                          '${index == current ? '› ' : ''}${items[index].title}${items[index].subtitle == null ? '' : ' · ${items[index].subtitle}'}',
                      onTap: () => onSelect(items[index].id),
                    ),
                  ),
                if (!loading.value &&
                    items.isEmpty &&
                    response.value.errors.isEmpty)
                  OiLabel.body(strings.noRecords),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
