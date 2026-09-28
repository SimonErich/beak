import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:signals/signals_flutter.dart';

import '../data/beak_data_changes.dart';
import '../data/beak_resource_repository.dart';
import '../filters/beak_filter_widget.dart';
import '../filters/beak_semantic_range_control.dart';
import '../formatting/beak_formatting.dart';
import '../localization/beak_localizations.dart';
import 'beak_list_definition.dart';
import 'beak_query_controller.dart';
import 'beak_saved_views.dart';

/// Region rendered by a composed list toolbar.
enum BeakListToolbarRegion {
  /// Both preset and filter rows.
  all,

  /// Preset tabs and overview toggle only.
  presets,

  /// Search, filter and saved-view controls only.
  controls,
}

/// Shared list controls; filters remain staged until the sheet is applied.
class BeakListToolbar extends HookWidget {
  /// Created automatically for a configured list definition.
  const BeakListToolbar({
    required this.controller,
    required this.definition,
    required this.source,
    required this.filters,
    this.headerVisible = true,
    this.onHeaderVisibleChanged,
    this.region = BeakListToolbarRegion.all,
    super.key,
  });

  /// Controller shared with the table and summary panels.
  final BeakQueryController controller;

  /// Presentation options.
  final BeakListDefinition definition;

  /// Panel-resolved source.
  final BeakDataSource source;

  /// Available typed filter editors.
  final List<BeakFilterDef> filters;

  /// Current overview visibility.
  final bool headerVisible;

  /// Updates overview visibility without changing data filtering.
  final ValueChanged<bool>? onHeaderVisibleChanged;

  /// Allows a summary region between presets and table controls.
  final BeakListToolbarRegion region;

  Future<void> _edit(BuildContext context, List<BeakFilterDef> fields) async {
    final applied = await OiSheet.showAsync<Map<String, BeakFilter>>(
      context,
      label: 'All filters',
      side: OiPanelSide.right,
      size: definition.filterSheetWidth,
      builder: (close) => BeakFilterEditor(
        controller: controller,
        filters: fields,
        source: source,
        savedViews: definition.savedViews,
        description: definition.filterDescription,
        advancedDescription: definition.advancedFilterDescription,
        advancedColumns: definition.advancedFilterColumns,
        recordNoun: definition.recordNoun,
        onClose: close,
      ),
    );
    if (applied != null && context.mounted && !controller.isDisposed) {
      controller.applyFilters(applied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final search = useTextEditingController(
      text: controller.state.value.search,
    );
    useEffect(
      () => effect(() {
        final value = controller.state.value.search;
        if (search.text != value) search.text = value;
      }),
      [controller, search],
    );
    return Watch((context) {
      final state = controller.state.value;
      final active = controller.effectiveFilters(state);
      final quickFilters =
          controller.presets
              .where((preset) => preset.key == state.preset)
              .firstOrNull
              ?.quickFilters ??
          definition.quickFilters;
      return Padding(
        padding: EdgeInsets.only(
          bottom: region == BeakListToolbarRegion.presets ? 12 : 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (region != BeakListToolbarRegion.controls &&
                definition.presets.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  final tabs = _PresetTabs(
                    controller: controller,
                    source: source,
                    showCount: definition.showPresetCounts,
                    loadCounts:
                        definition.showPresetCounts ||
                        definition.subtitleBuilder != null,
                  );
                  final toggle =
                      definition.showHeaderToggle &&
                          onHeaderVisibleChanged != null
                      ? OiSwitch(
                          label: 'Show charts',
                          labelLeading: true,
                          value: headerVisible,
                          onChanged: onHeaderVisibleChanged,
                        )
                      : null;
                  if (constraints.maxWidth < 500 && toggle != null) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        tabs,
                        const SizedBox(height: 8),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: toggle,
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: tabs),
                      ?toggle,
                    ],
                  );
                },
              ),
            if (region != BeakListToolbarRegion.presets) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final controls = <Widget>[
                    if (filters.isNotEmpty || definition.savedViews != null)
                      OiButton.secondary(
                        size: OiButtonSize.small,
                        label: 'All filters',
                        icon: OiIcons.slidersHorizontal,
                        onTap: () => _edit(context, filters),
                      ),
                    if (controller.availableColumns.isNotEmpty)
                      OiButton.secondary(
                        size: OiButtonSize.small,
                        label: 'Columns',
                        icon: OiIcons.columns3,
                        onTap: () => OiSheet.showAsync<void>(
                          context,
                          label: 'Columns',
                          side: OiPanelSide.right,
                          size: 360,
                          builder: (close) => _ColumnEditor(
                            controller: controller,
                            close: () => close(),
                          ),
                        ),
                      ),
                  ];
                  final searchInput = Semantics(
                    label: BeakLocalizations.of(context).search,
                    child: OiThemeScope(
                      data: context.theme.copyWith(
                        components: context.components.copyWith(
                          textInput:
                              (context.components.textInput ??
                                      const OiTextInputThemeData())
                                  .copyWith(
                                    height: context.theme.componentSizes.small,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                  ),
                        ),
                      ),
                      child: OiTextInput.search(
                        placeholder: definition.searchPlaceholder ?? 'Search…',
                        controller: search,
                        onChanged: controller.setSearch,
                      ),
                    ),
                  );
                  return constraints.maxWidth >= 650
                      ? Row(
                          children: [
                            if (definition.showSearch)
                              SizedBox(width: 360, child: searchInput),
                            const Spacer(),
                            for (final control in controls)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: control,
                              ),
                          ],
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (definition.showSearch)
                              SizedBox(
                                width: constraints.maxWidth,
                                child: searchInput,
                              ),
                            ...controls,
                          ],
                        );
                },
              ),
              if (quickFilters.isNotEmpty ||
                  state.filters.isNotEmpty ||
                  state.search.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final filter in quickFilters)
                        OiFilterChip(
                          label:
                              definition.quickFilterLabels[filter] ??
                              filter.label,
                          value: active[filter.key] == null
                              ? null
                              : _filterSummary(
                                  context,
                                  filter,
                                  active[filter.key]!,
                                ),
                          selected: active.containsKey(filter.key),
                          onTap: () => _edit(context, [filter]),
                          onRemove: active.containsKey(filter.key)
                              ? () => controller.removeFilter(filter.key)
                              : null,
                        ),
                      if (active.isNotEmpty || state.search.isNotEmpty)
                        OiButton.ghost(
                          size: OiButtonSize.small,
                          label: 'Clear all',
                          onTap: controller.clearFilters,
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      );
    });
  }
}

String _filterSummary(
  BuildContext context,
  BeakFilterDef definition,
  BeakFilter filter,
) {
  if (definition is BeakChoiceFilter) {
    final clauses = filter is BeakOrFilter ? filter.filters : [filter];
    final labels = [
      for (final choice in definition.options)
        if (clauses.any(
          (clause) =>
              jsonEncode(clause.toJson()) == jsonEncode(choice.filter.toJson()),
        ))
          choice.label,
    ];
    return labels.join(', ');
  }
  final formatting = BeakFormatting.of(context);
  String display(BeakValue? value) => value == null
      ? '…'
      : formatting.formatCell(
          definition.column,
          BeakRecord(values: {definition.column.key: value}),
        );
  if (definition is BeakSemanticRangeFilter) {
    final bounds = beakFilterRange(filter);
    for (final preset in definition.presets) {
      if (preset.lower == definition.column.semantic.tryDecode(bounds.$1) &&
          preset.upper == definition.column.semantic.tryDecode(bounds.$2)) {
        return preset.label;
      }
    }
    final lower = definition.column.semantic.tryDecode(bounds.$1);
    final lowerLabel = definition.presets
        .where(
          (preset) => preset.lower == lower && preset.lower == preset.upper,
        )
        .firstOrNull
        ?.label;
    return '${lowerLabel ?? display(bounds.$1)} – ${display(bounds.$2)}';
  }
  if (filter case BeakFieldFilter(:final value)) return display(value);
  return 'Active';
}

class _PresetTabs extends HookWidget {
  const _PresetTabs({
    required this.controller,
    required this.source,
    required this.showCount,
    required this.loadCounts,
  });
  final BeakQueryController controller;
  final BeakDataSource source;
  final bool showCount;
  final bool loadCounts;
  @override
  Widget build(BuildContext context) {
    final revision = useBeakDataRevision(source, table: controller.model.table);
    useEffect(() {
      if (loadCounts) controller.refreshPresetCounts(source);
      return null;
    }, [source, controller, revision, loadCounts]);
    final selected = controller.presets.indexWhere(
      (preset) => preset.key == controller.state.value.preset,
    );
    String label(BeakQueryPreset preset) {
      if (!showCount) return preset.label;
      final count = controller.presetCounts.value[preset.key];
      final formatted = count == null
          ? '—'
          : BeakFormatting.of(context).number(count);
      return '${preset.label} · $formatted';
    }

    return Watch(
      (context) => OiTabs(
        scrollable: true,
        tabs: [
          for (final preset in controller.presets)
            OiTabItem(
              label: preset.label,
              semanticLabel: label(preset),
              trailing: showCount
                  ? _PresetCount(
                      label: controller.presetCounts.value[preset.key] == null
                          ? '—'
                          : BeakFormatting.of(context).number(
                              controller.presetCounts.value[preset.key]!,
                            ),
                      color: preset.countColor,
                    )
                  : null,
            ),
        ],
        selectedIndex: selected < 0 ? 0 : selected,
        onSelected: (index) =>
            controller.selectPreset(controller.presets[index].key),
      ),
    );
  }
}

class _PresetCount extends StatelessWidget {
  const _PresetCount({required this.label, required this.color});
  final String label;
  final BeakColor color;

  @override
  Widget build(BuildContext context) {
    final swatch = switch (color) {
      BeakColor.primary => context.colors.primary,
      BeakColor.secondary => context.colors.accent,
      BeakColor.success => context.colors.success,
      BeakColor.warning => context.colors.warning,
      BeakColor.error => context.colors.error,
      BeakColor.info => context.colors.info,
      BeakColor.muted => null,
    };
    return OiSurface(
      color: swatch?.muted ?? context.colors.surfaceSubtle,
      borderRadius: BorderRadius.circular(4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: OiLabel.variant(
        label,
        variant: OiLabelVariant.caption,
        color: swatch?.base ?? context.colors.textMuted,
        style: context.textTheme.caption.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// A reusable staged editor with an authoritative result-count preview.
class BeakFilterEditor extends HookWidget {
  /// Closing without a value cancels; applying returns all staged predicates.
  const BeakFilterEditor({
    required this.controller,
    required this.filters,
    required this.source,
    required this.onClose,
    this.savedViews,
    this.description,
    this.advancedDescription,
    this.advancedColumns = 1,
    this.recordNoun = 'records',
    super.key,
  });

  /// Active list remains unchanged while this editor is open.
  final BeakQueryController controller;

  /// Typed filter declarations.
  final List<BeakFilterDef> filters;

  /// Source used for eligibility choices and preview counts.
  final BeakDataSource source;

  /// Optional saved-view store exposed with the staged filter review.
  final BeakSavedViewStore? savedViews;

  /// Optional explanation of the staged filter workflow.
  final String? description;

  /// Explains less-frequent filters without opening their editors.
  final String? advancedDescription;

  /// Number of columns in the expanded advanced section.
  final int advancedColumns;

  /// Plural noun used in the result-count action.
  final String recordNoun;

  /// Completes the editor without mutating the controller directly.
  final void Function([Map<String, BeakFilter>? value]) onClose;

  @override
  Widget build(BuildContext context) {
    final staged = useState(
      controller.effectiveFilters(controller.state.value),
    );
    final valid = useState(true);
    final reset = useState(0);
    final count = useState<int?>(null);
    final loading = useState(true);
    final error = useState<BeakException?>(null);
    final candidateState = controller.previewFilters(staged.value);
    final candidate = controller
        .queryFor(candidateState)
        .paginate(page: 1, perPage: 1);
    useEffect(() {
      var current = true;
      loading.value = true;
      error.value = null;
      BeakResourceRepository(source).query(candidate).then((result) {
        if (!current) return;
        switch (result) {
          case BeakOk(:final value):
            count.value = value.total;
          case BeakErr(error: final failure):
            error.value = failure;
        }
        loading.value = false;
      });
      return () => current = false;
    }, [source, candidate, reset.value]);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Expanded(child: OiLabel.h2('All filters')),
                OiTappable(
                  semanticLabel: BeakLocalizations.of(context).close,
                  onTap: () => onClose(),
                  child: const SizedBox.square(
                    dimension: 28,
                    child: Center(child: OiIcon.raw(OiIcons.x, size: 16)),
                  ),
                ),
              ],
            ),
          ),
          if (description case final String text) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: OiLabel.body(text, color: context.colors.textMuted),
            ),
          ],
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BeakFilterBar(
                    key: ValueKey(reset.value),
                    filters: filters,
                    stacked: true,
                    dataSource: source,
                    countQueryFor: (filter) => controller.queryFor(
                      candidateState,
                      excludingFilter: filter.key,
                    ),
                    advancedDescription: advancedDescription,
                    advancedColumns: advancedColumns,
                    initialValues: staged.value,
                    onChanged: (_) {},
                    onValidityChanged: (value) => valid.value = value,
                    onFiltersChanged: (values) => staged.value = values,
                  ),
                  if (error.value case final BeakException failure)
                    OiEmptyState.error(
                      description: BeakLocalizations.of(
                        context,
                      ).errorMessage(failure),
                      actionLabel: BeakLocalizations.of(context).retry,
                      onAction: () => reset.value++,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OiDivider(color: context.colors.borderSubtle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OiButton.ghost(
                  label: 'Clear all',
                  onTap: () {
                    staged.value = {};
                    valid.value = true;
                    reset.value++;
                  },
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (savedViews case final BeakSavedViewStore store)
                      BeakSavedViews(
                        store: store,
                        controller: controller,
                        source: source,
                        saveState: candidateState,
                        showSelector: false,
                        saveLabel: 'Save as view',
                        enabled: valid.value,
                        onSelected: () => onClose(),
                      ),
                    OiButton.primary(
                      label: count.value == null
                          ? 'Apply filters'
                          : 'Show ${count.value} $recordNoun',
                      loading: loading.value,
                      onTap:
                          loading.value || error.value != null || !valid.value
                          ? null
                          : () => onClose(staged.value),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColumnEditor extends HookWidget {
  const _ColumnEditor({required this.controller, required this.close});
  final BeakQueryController controller;
  final VoidCallback close;
  @override
  Widget build(BuildContext context) {
    final selected = useState({
      for (final column in controller.currentColumns) column.key,
    });
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OiLabel.h3('Columns'),
          for (final column in controller.availableColumns)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: OiCheckbox(
                label: column.label,
                value: selected.value.contains(column.key),
                onChanged: (value) {
                  final next = {...selected.value};
                  if (value) {
                    next.add(column.key);
                  } else {
                    next.remove(column.key);
                  }
                  selected.value = next;
                },
              ),
            ),
          Wrap(
            spacing: 8,
            children: [
              OiButton.ghost(label: 'Cancel', onTap: close),
              OiButton.primary(
                label: 'Apply columns',
                onTap: selected.value.isEmpty
                    ? null
                    : () {
                        controller.chooseColumns([
                          for (final column in controller.availableColumns)
                            if (selected.value.contains(column.key)) column,
                        ]);
                        close();
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
