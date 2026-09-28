import '../presentation/beak_record_template.dart';
import '../actions/beak_model_action_runner.dart';
import '../auth/beak_auth_adapter.dart';
import '../auth/beak_session_store.dart';
import '../query/beak_list_definition.dart';
import '../formatting/beak_formatting.dart';
import '../query/beak_list_export.dart';
import '../presentation/beak_action_presentation.dart';
import '../panel/beak_back_button.dart';
import '../form/beak_form_session.dart';
import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:signals/signals_flutter.dart';

import '../actions/beak_action.dart';
import '../localization/beak_localizations.dart';
import '../detail/beak_default_detail_layout.dart';
import '../actions/beak_action_button.dart';
import '../blocks/beak_block_host.dart';
import '../blocks/beak_block.dart';
import '../data/beak_relation_loads.dart';
import '../data/beak_data_changes.dart';
import '../di/beak_locator.dart';
import '../data/beak_resource_repository.dart';
import '../data/reference_cache.dart';
import '../detail/beak_record_scope.dart';
import '../detail/relation_manager.dart';
import '../filters/beak_filter_widget.dart';
import '../form/beak_configured_form.dart';
import '../form/beak_form_layout.dart';
import '../panel/beak_resource_screen.dart';
import '../panel/beak_panel_config.dart';
import '../panel/beak_resource_view.dart';
import '../panel/beak_routes.dart';
import '../table/beak_data_table.dart';
import '../table/beak_table_action.dart';
import '../table/table_view_model.dart';
import 'beak_page_scaffold.dart';
import '../query/beak_query_controller.dart';
import '../query/beak_query_scope.dart';
import '../query/beak_list_toolbar.dart';

/// The generated list page: the resource's filter bar, its global actions
/// (create built in), and a [BeakDataTable] whose rows navigate to the
/// show page — declaring a [BeakResource] is all it takes.
class BeakResourceListPage extends HookWidget {
  /// Creates the list page for [resource] over [dataSource].
  const BeakResourceListPage({
    required this.resource,
    required this.dataSource,
    super.key,
  });

  /// The resource this page lists.
  final BeakResource resource;

  /// The source queries and mutations run against.
  final BeakDataSource dataSource;

  @override
  Widget build(BuildContext context) {
    final filter = useState<BeakFilter?>(null);
    final generation = useState(0);
    final tableViewModel = useRef<TableViewModel?>(null);
    final selection = useState<BeakTableSelection?>(null);
    final BeakModel model = resource.model;
    final tableScreen = switch (resource.screenFor(BeakScreenRole.list)) {
      final BeakTableScreen screen => screen,
      _ => null,
    };
    final definition = tableScreen?.definition;
    final filters = definition != null && definition.filters.isNotEmpty
        ? definition.filters
        : resource.effectiveFilters;
    final sharedQuery = useMemoized(
      () => definition == null
          ? null
          : BeakQueryController(
              model: model,
              base: tableScreen?.query,
              presets: definition.presets,
              columns: definition.columns.isNotEmpty
                  ? definition.columns
                  : [
                      for (final field
                          in tableScreen?.fields ??
                              const <BeakScalarField<Object>>[])
                        BeakTableColumn.field(field),
                    ],
              searchFields: resource.globalSearchSources,
              initial: BeakQueryState(
                preset: definition.initialPreset,
                showHeader: definition.headerInitiallyVisible,
                sorts: tableScreen?.query?.sorts ?? const [],
                perPage:
                    tableScreen?.query?.pagination.perPage ??
                    definition.pageSize,
              ),
            ),
      [model, dataSource, definition, tableScreen?.query],
    );
    useEffect(() => sharedQuery?.dispose, [sharedQuery]);
    final GoRouter router = GoRouter.of(context);
    final actionContext = BeakActionContext(
      buildContext: context,
      model: model,
      dataSource: dataSource,
      router: router,
      refresh: () async => generation.value += 1,
      stageRemoval: (id) {
        final viewModel = tableViewModel.value;
        final removed = viewModel == null || viewModel.isDisposed
            ? null
            : viewModel.removeLocally(id);
        return () {
          if (removed != null && viewModel != null && !viewModel.isDisposed) {
            viewModel.insertLocally(removed.record, removed.index);
          }
        };
      },
      onError: resource.onActionError,
      canExecute: resource.allowsAction,
    );

    final repository = BeakResourceRepository(dataSource);

    Future<List<BeakRecord>?> recordsOf(List<Object> ids) async {
      final result = ids.length == 1
          ? (await repository.getOne(
              model.table,
              ids.single,
            )).map((record) => [record])
          : await repository.batchGet(model.table, ids);
      return switch (result) {
        BeakOk(:final value) => value,
        BeakErr(:final error) => () {
          actionContext.reportError(error);
          return null;
        }(),
      };
    }

    BeakTableAction rowAction(BeakRecordAction action) => BeakTableAction(
      id: action.key,
      label: beakActionLabel(action, context),
      icon: action.icon,
      destructive: action.color == BeakColor.error,
      visibleWhen: switch (action) {
        BeakEditAction() => model.behavior.editableWhen,
        BeakDeleteAction() => model.behavior.deletableWhen,
        _ => null,
      },
      onRun: (ids) async {
        if (!actionContext.checkPermission(action)) return;
        // The built-in view/edit actions only navigate by id — the row
        // already rendered from the full record, so re-fetching it before
        // dispatch would be a wasted round-trip.
        switch (action) {
          case BeakViewAction():
            for (final id in ids) {
              router.go(
                _withReturnTo(router, BeakRoutes.show(model.table, id)),
              );
            }
          case BeakEditAction():
            for (final id in ids) {
              router.go(
                _withReturnTo(router, BeakRoutes.edit(model.table, id)),
              );
            }
          case BeakDeleteAction() || BeakArchiveAction():
            // These built-ins confirm and mutate by identity only. The server
            // validates current state during the write; a preflight GET would
            // add latency without making that decision atomic.
            for (final id in ids) {
              await executeBeakAction(
                action: action,
                context: actionContext,
                record: BeakRecord(
                  values: {model.primaryKey.key: BeakValue.of(id)},
                ),
              );
            }
          default:
            for (final record in await recordsOf(ids) ?? const <BeakRecord>[]) {
              await executeBeakAction(
                action: action,
                context: actionContext,
                record: record,
              );
            }
        }
      },
    );

    BeakTableAction bulkAction(BeakBulkAction action) => BeakTableAction(
      id: action.key,
      label: action.label,
      icon: action.icon,
      destructive: action.color == BeakColor.error,
      onRun: (ids) async {
        if (!actionContext.checkPermission(action)) return;
        final records = await recordsOf(ids);
        if (records == null) return;
        await executeBeakAction(
          action: action,
          context: actionContext,
          records: records,
        );
      },
    );

    Widget content() {
      var spec =
          sharedQuery?.query ??
          tableScreen?.query ??
          BeakQuerySpec(table: model.table);
      final base = spec.filter;
      final combined = switch ((base, filter.value)) {
        (final BeakFilter a, final BeakFilter b) => BeakAndFilter([a, b]),
        (_, final BeakFilter b) => b,
        _ => base,
      };
      if (combined case final BeakFilter active) {
        spec = BeakQuerySpec(
          table: spec.table,
          filter: active,
          sorts: spec.sorts,
          search: spec.search,
          relationLoads: spec.relationLoads,
          pagination: spec.pagination,
          withTrashed: spec.withTrashed,
        );
      }

      final availableBulkActions = <BeakTableAction>[
        for (final action in resource.bulkActions) bulkAction(action),
        for (final name in {
          ...?definition?.bulkModelActions,
          for (final presentation
              in definition?.bulkActions ?? const <BeakActionPresentation>[])
            if (presentation.key.startsWith('model:'))
              presentation.key.substring(6),
        })
          BeakTableAction(
            id: 'model:$name',
            label: model.behavior.action(name).label,
            icon: OiIcons.play,
            onRun: (ids) async {
              final action = model.behavior.action(name);
              final confirmed = await showOiDialog<bool>(
                context,
                builder: (context, close) => OiDialog.confirm(
                  label: action.label,
                  title: action.label,
                  content: OiLabel.body(
                    'Apply ${action.label} to ${ids.length} selected records? Each record is saved independently.',
                  ),
                  actions: [
                    OiButton.ghost(label: 'Cancel', onTap: () => close(false)),
                    OiButton.primary(
                      label: action.label,
                      onTap: () => close(true),
                    ),
                  ],
                  onClose: () => close(false),
                ),
              );
              if (confirmed != true || !context.mounted) return;
              BeakRecord? arguments = action.inputModel == null
                  ? const BeakRecord(values: {})
                  : null;
              var cancelled = false;
              var changed = false;
              final failures = <String>[];
              for (final id in ids) {
                if (!context.mounted || cancelled) break;
                await _executeModelAction(
                  context: context,
                  model: model,
                  source: dataSource,
                  recordId: id,
                  action: action,
                  onError: (error) => failures.add('$id: ${error.message}'),
                  onComplete: () => changed = true,
                  prepare: (session) async {
                    if (arguments != null) return arguments;
                    arguments = await showBeakActionInput(
                      context,
                      session,
                      action,
                    );
                    cancelled = arguments == null;
                    return arguments;
                  },
                );
              }
              if (!context.mounted) return;
              if (changed) generation.value++;
              if (failures.isNotEmpty) {
                actionContext.reportError(
                  BeakValidationException(failures.join('\n')),
                );
              }
            },
          ),
      ];
      if (definition?.export case final export?) {
        availableBulkActions.add(
          BeakTableAction(
            id: 'export',
            label: export.label,
            icon: OiIcons.download,
            onRun: (ids) async {
              final query = sharedQuery?.query ?? spec;
              final selected = BeakOrFilter([
                for (final id in ids)
                  BeakFieldFilter(
                    column: model.primaryKey,
                    operator: BeakOperator.eq,
                    value: BeakValue.of(id),
                  ),
              ]);
              final result = await repository.run(
                () => export.download(
                  query: query.withFilter(selected),
                  model: model,
                  source: dataSource,
                  formatting: BeakFormatting.of(context),
                ),
              );
              if (result case BeakErr(:final error)) {
                actionContext.reportError(error);
              }
            },
          ),
        );
      }
      final configuredBulkActions = definition?.bulkActions == null
          ? availableBulkActions
          : _configureActionPresentations(
              definition!.bulkActions!,
              availableBulkActions,
            );
      final Widget table = BeakDataTable(
        rowHeight: sharedQuery?.presets
            .where((preset) => preset.key == sharedQuery.state.value.preset)
            .firstOrNull
            ?.rowHeight,
        key: ValueKey((filter.value, generation.value)),
        model: model,
        dataSource: dataSource,
        enableDelete: false,
        onViewModel: (viewModel) => tableViewModel.value = viewModel,
        initialSpec: spec,
        baseFilter: sharedQuery == null ? combined : null,
        fields: tableScreen?.fields,
        queryController: sharedQuery,
        presentations: sharedQuery == null || sharedQuery.currentColumns.isEmpty
            ? null
            : sharedQuery.currentColumns,
        showHeaderFilters: filters.isEmpty,
        onRowTap: (record) {
          final Object? id = model.primaryKeyOf(record);
          if (id != null) {
            router.go(_withReturnTo(router, BeakRoutes.show(model.table, id)));
          }
        },
        onOpenRelation: (relation, related) {
          final Object? id = related['id']?.raw;
          if (id != null) {
            router.go(BeakRoutes.show(relation.relatedTable, id));
          }
        },
        actions: _presentActions(definition, [
          rowAction(const BeakViewAction()),
          if (resource.allowsEdit) rowAction(const BeakEditAction()),
          if (resource.allowsDelete) rowAction(resource.deleteAction),
          for (final action in resource.recordActions)
            if (action.roles.contains(BeakScreenRole.list)) rowAction(action),
          if (resource.allowsCreate && resource.duplication != null)
            BeakTableAction(
              id: 'duplicate',
              label: 'Duplicate',
              icon: OiIcons.copy,
              onRun: (ids) async {
                if (ids.isEmpty) return;
                final registry =
                    beakDependencies(context).isRegistered<BeakModelRegistry>()
                    ? beakDependencies(context)<BeakModelRegistry>()
                    : BeakModelRegistry();
                if (registry.byTable(model.table) == null) {
                  registry.register(model);
                }
                final result = await repository.run(
                  () =>
                      BeakRecordDuplicator(
                        source: dataSource,
                        registry: registry,
                      ).duplicate(
                        model,
                        BeakRecord(
                          values: {
                            model.primaryKey.key: BeakValue.of(ids.single),
                          },
                        ),
                        saveId:
                            'duplicate-${DateTime.now().microsecondsSinceEpoch}',
                        spec: resource.duplication!,
                      ),
                );
                if (!context.mounted) return;
                switch (result) {
                  case BeakOk(:final value):
                    router.go(
                      BeakRoutes.create(model.table),
                      extra: value.record,
                    );
                  case BeakErr(:final error):
                    actionContext.reportError(error);
                }
              },
            ),
          if (resource.allowsEdit)
            for (final action in model.behavior.actions)
              BeakTableAction(
                id: 'model:${action.name}',
                label: action.label,
                icon: OiIcons.play,
                visibleWhen: action.isAvailable,
                onRun: (ids) async {
                  for (final id in ids) {
                    if (!context.mounted) return;
                    await _executeModelAction(
                      context: context,
                      model: model,
                      source: dataSource,
                      recordId: id,
                      action: action,
                      onError: actionContext.reportError,
                      onComplete: () => generation.value++,
                    );
                  }
                },
              ),
        ]),
        showStatusBar: definition?.showTableStatusBar ?? true,
        pageSizeOptions: definition?.pageSizeOptions ?? const [10, 25, 50, 100],
        bulkActions: configuredBulkActions,
        shrinkWrap:
            definition?.scrollMode == BeakListScrollMode.page ||
            (definition?.fitTableToRows ?? false),
        showBulkActionBar: !(definition?.floatingBulkActions ?? false),
        onSelectionChanged: (value) => selection.value = value,
      );

      final pageActions = <Widget>[
        if (definition?.export case final BeakListExport export)
          BeakListExportButton(
            definition: export,
            controller: sharedQuery!,
            source: dataSource,
          ),
        for (final action in resource.globalActions)
          BeakActionButton(action: action, actionContext: actionContext),
        if (resource.allowsCreate)
          if (definition?.createLabel case final String label)
            OiButton.primary(
              label: label,
              icon: OiIcons.plus,
              onTap: () => router.go(
                _withReturnTo(router, BeakRoutes.create(model.table)),
              ),
            )
          else
            BeakActionButton(
              action: const BeakCreateAction(),
              actionContext: actionContext,
            ),
      ];
      if (sharedQuery != null && definition != null) {
        final overview =
            (sharedQuery.state.value.showHeader ??
                definition.headerInitiallyVisible)
            ? definition.header
            : definition.collapsedHeader;
        final pageScroll = definition.scrollMode == BeakListScrollMode.page;
        final page = OiPageLayout(
          scrollable: pageScroll,
          scrollHeaderWhenCompact: pageScroll,
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 700 ? 16 : 32,
            8,
            MediaQuery.sizeOf(context).width < 700 ? 16 : 32,
            24,
          ),
          header: OiPageHeader(
            title: definition.title ?? resource.effectiveLabel,
            subtitle:
                definition.subtitleBuilder?.call(
                  sharedQuery.presetCounts.value,
                ) ??
                definition.subtitle,
            titleVariant: OiLabelVariant.h1,
            padding: EdgeInsets.zero,
            actionAlignment: CrossAxisAlignment.end,
            actions: pageActions,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 700;
              final tableSurface = OiCard(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
                child: Column(
                  mainAxisSize:
                      compact || pageScroll || definition.fitTableToRows
                      ? MainAxisSize.min
                      : MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: BeakListToolbar(
                        region: BeakListToolbarRegion.controls,
                        controller: sharedQuery,
                        definition: definition,
                        source: dataSource,
                        filters: filters,
                      ),
                    ),
                    if (pageScroll)
                      table
                    else if (compact)
                      // Keep a useful row viewport when wrapping filters and
                      // overview cards exceed the available page height.
                      SizedBox(
                        height: constraints.maxHeight.clamp(360.0, 560.0),
                        child: table,
                      )
                    else
                      Flexible(
                        fit: definition.fitTableToRows
                            ? FlexFit.loose
                            : FlexFit.tight,
                        child: table,
                      ),
                  ],
                ),
              );
              final body = Column(
                mainAxisSize: compact || pageScroll
                    ? MainAxisSize.min
                    : MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BeakListToolbar(
                    region: BeakListToolbarRegion.presets,
                    controller: sharedQuery,
                    definition: definition,
                    source: dataSource,
                    filters: filters,
                    headerVisible:
                        sharedQuery.state.value.showHeader ??
                        definition.headerInitiallyVisible,
                    onHeaderVisibleChanged: sharedQuery.setHeaderVisible,
                  ),
                  if (overview != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 24),
                      child: BeakBlockHost(block: overview),
                    ),
                  if (compact || pageScroll)
                    tableSurface
                  else
                    Flexible(
                      fit: definition.fitTableToRows
                          ? FlexFit.loose
                          : FlexFit.tight,
                      child: tableSurface,
                    ),
                ],
              );
              return compact && !pageScroll
                  ? SingleChildScrollView(child: body)
                  : body;
            },
          ),
        );
        if (!definition.floatingBulkActions) return page;
        return Stack(
          fit: StackFit.expand,
          children: [
            page,
            if (selection.value case final BeakTableSelection selected)
              if (selected.ids.isNotEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 32,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: _FloatingSelectionBar(
                      recordNoun: definition.recordNoun,
                      actions: configuredBulkActions,
                      selection: selected,
                    ),
                  ),
                ),
          ],
        );
      }
      return BeakPageScaffold(
        resource: resource,
        variant: OiResourcePageVariant.list,
        actions: pageActions,
        filters: sharedQuery != null
            ? null
            : switch (filters) {
                [] => null,
                final List<BeakFilterDef> active => BeakFilterBar(
                  filters: active,
                  dataSource: dataSource,
                  onChanged: (combined) => filter.value = combined,
                ),
              },
        child: sharedQuery != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (definition!.header case final BeakBlock header)
                    BeakBlockHost(block: header),
                  BeakListToolbar(
                    controller: sharedQuery,
                    definition: definition,
                    source: dataSource,
                    filters: filters,
                  ),
                  Expanded(child: table),
                ],
              )
            : resource.viewModes.length <= 1
            ? table
            : _ViewModeSwitcher(
                viewModes: resource.viewModes,
                model: model,
                table: table,
              ),
      );
    }

    return sharedQuery == null
        ? content()
        : BeakQueryScope(
            controller: sharedQuery,
            persistInUrl: definition!.persistQueryInUrl,
            child: Watch.builder(builder: (_) => content()),
          );
  }
}

/// The list page's view-mode switcher: an `OiSegmentedControl` over a
/// resource's [viewModes], rendering the selected mode's block (or the
/// full [table] for the table view) beneath it.
class _ViewModeSwitcher extends HookWidget {
  const _ViewModeSwitcher({
    required this.viewModes,
    required this.model,
    required this.table,
  });

  final List<BeakResourceView> viewModes;
  final BeakModel model;
  final Widget table;

  @override
  Widget build(BuildContext context) {
    final selected = useState(0);
    final int index = selected.value.clamp(0, viewModes.length - 1);
    final BeakResourceView current = viewModes[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: OiSegmentedControl<int>(
            segments: [
              for (var i = 0; i < viewModes.length; i++)
                OiSegment(
                  value: i,
                  label: viewModes[i].label,
                  icon: viewModes[i].icon,
                ),
            ],
            selected: index,
            onChanged: (value) => selected.value = value,
          ),
        ),
        Expanded(
          child: switch (current) {
            BeakTableView() => table,
            _ => BeakBlockHost(block: current.build(model)),
          },
        ),
      ],
    );
  }
}

/// The generated show page: the record rendered through the resource's
/// [BeakResource.effectiveDetail] layout, with edit and delete actions.
///
/// The record and the relations that layout renders arrive in one query, and
/// each [BeakRelationManager] is handed the rows already loaded for it.
class BeakResourceShowPage extends HookWidget {
  /// Creates the show page for [recordId] of [resource].
  const BeakResourceShowPage({
    required this.resource,
    required this.dataSource,
    required this.recordId,
    super.key,
  });

  /// The resource this page shows a record of.
  final BeakResource resource;

  /// The source the record loads from.
  final BeakDataSource dataSource;

  /// Primary key of the record on display.
  final Object recordId;

  @override
  Widget build(BuildContext context) {
    final screen = resource.screenFor(BeakScreenRole.read);
    if (screen is BeakFormScreen) {
      return _formScaffold(
        form: screen,
        resource: resource,
        variant: OiResourcePageVariant.show,
        child: BeakConfiguredForm(
          frameBuilder: _pageFrame(
            screen,
            resource,
            OiResourcePageVariant.show,
          ),
          onClose: () => context.go(
            BeakBackButton.destination(
              GoRouterState.of(context).uri,
              resource.route,
            ),
          ),
          filePicker: resource.filePicker,
          uploader: resource.uploader,
          registry: beakDependencies(context).isRegistered<BeakModelRegistry>()
              ? beakDependencies(context)<BeakModelRegistry>()
              : null,
          model: resource.model,
          dataSource: dataSource,
          recordId: recordId,
          mode: BeakFormMode.read,
          canEdit: resource.allowsEdit,
          submitAction: screen.submitAction,
          submitLabel: screen.submitLabel,
          submitIcon: screen.submitIcon,
          outlinedCancel: screen.outlinedCancel,
          showActionsWhileEditing: screen.showActionsWhileEditing,
          editLabel: screen.editLabel,
          prominentEdit: screen.prominentEdit,
          compactActions: screen.compactActions,
          showChangeBar: screen.showChangeBar,
          header: screen.header,
          recordHeader: screen.recordHeader,
          aside: screen.aside,
          asideWidth: screen.asideWidth,
          asideFraction: screen.asideFraction,
          asideFooter: screen.asideFooter,
          footer: screen.footer,
          navigation: screen.navigation,
          navigationDescription: screen.navigationDescription,
          layout: screen.layout,
          steps: screen.steps,
          drafts: screen.drafts,
          reviewBeforeSave: screen.reviewBeforeSave,
          showInspector: screen.showInspector,
        ),
      );
    }
    final BeakModel model = resource.model;
    final record = useState<BeakRecord?>(null);
    final generation = useState(0);
    final failure = useState<BeakException?>(null);
    final dataRevision = useBeakDataRevision(dataSource, table: model.table);
    useEffect(() {
      record.value = null;
      failure.value = null;
      var cancelled = false;
      Future<void> load() async {
        // One query for the record *and* the relations this page renders.
        // A custom detail layout renders whichever blocks it names, which
        // the page cannot know statically — those blocks load their own.
        final result = await beakLoadRecordWithRelations(
          BeakResourceRepository(dataSource),
          model: model,
          id: recordId,
          relations: resource.detail != null
              ? const []
              : [
                  for (final relation in model.relationships)
                    if (relation.cardinality == BeakRelationCardinality.many)
                      relation,
                ],
        );
        if (cancelled) {
          return;
        }
        switch (result) {
          case BeakOk(:final value):
            record.value = value;
          case BeakErr(:final error):
            failure.value = error;
        }
      }

      load();
      return () => cancelled = true;
    }, [dataSource, recordId, generation.value, dataRevision]);

    final actionContext = BeakActionContext(
      buildContext: context,
      model: model,
      dataSource: dataSource,
      router: GoRouter.of(context),
      refresh: () async => generation.value++,
      onError: resource.onActionError,
      canExecute: resource.allowsAction,
    );

    final BeakRecord? loaded = record.value;
    return BeakPageScaffold(
      resource: resource,
      variant: OiResourcePageVariant.show,
      surface: false,
      title: '${resource.effectiveLabel} $recordId',
      actions: [
        if (loaded != null) ...[
          if (resource.allowsEdit &&
              (model.behavior.editableWhen?.call(loaded) ?? true))
            BeakActionButton(
              action: const BeakEditAction(),
              actionContext: actionContext,
              record: loaded,
            ),
          if (resource.allowsDelete &&
              (model.behavior.deletableWhen?.call(loaded) ?? true))
            BeakActionButton(
              action: resource.deleteAction,
              actionContext: actionContext,
              record: loaded,
            ),
          if (resource.allowsEdit)
            for (final action in model.behavior.actions)
              if (action.isAvailable(loaded))
                _ModelActionButton(
                  action: action,
                  onRun: () => _executeModelAction(
                    context: context,
                    model: model,
                    source: dataSource,
                    recordId: recordId,
                    action: action,
                    onError: actionContext.reportError,
                    onComplete: () => generation.value++,
                  ),
                ),
          for (final action in resource.recordActions)
            if (action.roles.contains(BeakScreenRole.read))
              BeakActionButton(
                action: action,
                actionContext: actionContext,
                record: loaded,
              ),
        ],
      ],
      child: switch ((loaded, failure.value)) {
        (null, null) => OiLabel.body(BeakLocalizations.of(context).loading),
        (null, final BeakException error) => OiEmptyState.error(
          description: error.message,
        ),
        // The layout the resource declared, or the one its model implies —
        // rendered inside the loaded record's scope so its field blocks
        // resolve.
        (final BeakRecord value, _) => SingleChildScrollView(
          child: BeakRecordScope(
            model: model,
            record: value,
            child: BeakBlockHost(
              block:
                  resource.detail ??
                  beakDefaultDetailLayout(
                    model,
                    localizations: BeakLocalizations.of(context),
                  ),
            ),
          ),
        ),
      },
    );
  }
}

/// The generated create page: a [BeakConfiguredForm] in create mode that
/// navigates back to the list after saving.
class BeakResourceCreatePage extends HookWidget {
  /// Creates the create page for [resource].
  const BeakResourceCreatePage({
    required this.resource,
    required this.dataSource,
    this.referenceCache,
    super.key,
  });

  /// The resource this page creates records of.
  final BeakResource resource;

  /// The source the form submits through.
  final BeakDataSource dataSource;

  /// Resolves the belongs-to pickers' prefilled keys through one batched
  /// fetch; without it each picker resolves its own.
  final ReferenceCache? referenceCache;

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter.of(context);
    final screen = resource.screenFor(BeakScreenRole.create);
    final form = screen is BeakFormScreen ? screen : null;
    return _formScaffold(
      form: form,
      resource: resource,
      variant: OiResourcePageVariant.create,
      title: BeakLocalizations.of(context).createTitle(resource.effectiveLabel),
      child: BeakConfiguredForm(
        frameBuilder: _pageFrame(form, resource, OiResourcePageVariant.create),
        onClose: () => router.go(
          BeakBackButton.destination(
            GoRouterState.of(context).uri,
            resource.route,
          ),
        ),
        filePicker: resource.filePicker,
        uploader: resource.uploader,
        registry: beakDependencies(context).isRegistered<BeakModelRegistry>()
            ? beakDependencies(context)<BeakModelRegistry>()
            : null,
        model:
            resource.createModel ??
            resource.model.createModel ??
            resource.model,
        dataSource: dataSource,
        mode: BeakFormMode.create,
        initialValues: switch (GoRouterState.of(context).extra) {
          final BeakRecord record => record,
          _ => null,
        },
        submitAction: form?.submitAction,
        submitLabel: form?.submitLabel,
        submitIcon: form?.submitIcon,
        outlinedCancel: form?.outlinedCancel ?? false,
        showActionsWhileEditing: form?.showActionsWhileEditing ?? true,
        editLabel: form?.editLabel,
        prominentEdit: form?.prominentEdit ?? false,
        compactActions: form?.compactActions ?? false,
        showChangeBar: form?.showChangeBar ?? false,
        header: form?.header,
        recordHeader: form?.recordHeader,
        aside: form?.aside,
        asideWidth: form?.asideWidth ?? 360,
        asideFraction: form?.asideFraction,
        asideFooter: form?.asideFooter,
        footer: form?.footer,
        navigation: form?.navigation ?? BeakWizardNavigation.inline,
        navigationDescription: form?.navigationDescription,
        layout: form?.layout,
        steps: form?.steps ?? const [],
        drafts: form?.drafts,
        reviewBeforeSave: form?.reviewBeforeSave ?? false,
        showInspector: form?.showInspector ?? false,
        fields: resource.createFields,
        valueMode: resource.formValueMode,
        onSaved: (_) => router.go(
          BeakBackButton.destination(
            GoRouterState.of(context).uri,
            resource.route,
          ),
        ),
      ),
    );
  }
}

/// The generated edit page: a [BeakConfiguredForm] prefilled from `getOne` that
/// navigates to the record's show page after saving.
class BeakResourceEditPage extends HookWidget {
  /// Creates the edit page for [recordId] of [resource].
  const BeakResourceEditPage({
    required this.resource,
    required this.dataSource,
    required this.recordId,
    this.referenceCache,
    super.key,
  });

  /// The resource this page edits a record of.
  final BeakResource resource;

  /// The source the form loads and submits through.
  final BeakDataSource dataSource;

  /// Resolves the belongs-to pickers' prefilled keys through one batched
  /// fetch; without it each picker resolves its own.
  final ReferenceCache? referenceCache;

  /// Primary key of the record under edit.
  final Object recordId;

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter.of(context);
    final editSource = switch (dataSource) {
      final BeakEditDataSource source => source,
      _ => null,
    };
    final editLoader = useMemoized(
      () =>
          resource.editValues ??
          (resource.model.editModel != null && editSource != null
              ? (Object id) =>
                    editSource.loadEditValues(resource.model.table, id)
              : null),
      [resource.editValues, resource.model, editSource],
    );
    final screen = resource.screenFor(BeakScreenRole.edit);
    final form = screen is BeakFormScreen ? screen : null;
    return _formScaffold(
      form: form,
      resource: resource,
      variant: OiResourcePageVariant.edit,
      child: BeakConfiguredForm(
        frameBuilder: _pageFrame(form, resource, OiResourcePageVariant.edit),
        onClose: () => router.go(
          BeakBackButton.destination(
            GoRouterState.of(context).uri,
            resource.route,
          ),
        ),
        filePicker: resource.filePicker,
        uploader: resource.uploader,
        registry: beakDependencies(context).isRegistered<BeakModelRegistry>()
            ? beakDependencies(context)<BeakModelRegistry>()
            : null,
        model: resource.editModel ?? resource.model.editModel ?? resource.model,
        dataSource: dataSource,
        recordId: recordId,
        mode: BeakFormMode.edit,
        submitAction: form?.submitAction,
        submitLabel: form?.submitLabel,
        submitIcon: form?.submitIcon,
        outlinedCancel: form?.outlinedCancel ?? false,
        showActionsWhileEditing: form?.showActionsWhileEditing ?? true,
        editLabel: form?.editLabel,
        prominentEdit: form?.prominentEdit ?? false,
        compactActions: form?.compactActions ?? false,
        showChangeBar: form?.showChangeBar ?? false,
        header: form?.header,
        recordHeader: form?.recordHeader,
        aside: form?.aside,
        asideWidth: form?.asideWidth ?? 360,
        asideFraction: form?.asideFraction,
        asideFooter: form?.asideFooter,
        footer: form?.footer,
        navigation: form?.navigation ?? BeakWizardNavigation.inline,
        navigationDescription: form?.navigationDescription,
        layout: form?.layout,
        steps: form?.steps ?? const [],
        drafts: form?.drafts,
        reviewBeforeSave: form?.reviewBeforeSave ?? false,
        showInspector: form?.showInspector ?? false,
        fields: resource.editFields,
        valueMode: resource.formValueMode,
        editValues: editLoader,
        onSaved: (_) =>
            router.go(BeakRoutes.show(resource.model.table, recordId)),
      ),
    );
  }
}

/// Reuses the form transaction for commands from any generated record surface.
Future<void> _executeModelAction({
  required BuildContext context,
  required BeakModel model,
  required BeakDataSource source,
  required Object recordId,
  required BeakModelAction action,
  required void Function(BeakException) onError,
  required VoidCallback onComplete,
  Future<BeakRecord?> Function(BeakFormSession)? prepare,
}) async {
  final dependencies = beakDependencies(context);
  final config = dependencies<BeakPanelConfig>();
  final auth =
      config.auth?.adapter ??
      (dependencies.isRegistered<BeakSessionStore>()
          ? dependencies<BeakSessionStore>()
          : null);
  final principal = switch (auth?.state.value) {
    BeakAuthAuthenticated(:final identity) => identity.id,
    _ => null,
  };
  final outcome = await dependencies<BeakModelActionRunner>().execute(
    model: model,
    source: source,
    recordId: recordId,
    action: action,
    principal: principal,
    registry: dependencies.isRegistered<BeakModelRegistry>()
        ? dependencies<BeakModelRegistry>()
        : null,
    prepare: (session) async {
      if (!context.mounted) return null;
      final arguments =
          await (prepare?.call(session) ??
              showBeakActionInput(context, session, action));
      final currentPrincipal = switch (auth?.state.value) {
        BeakAuthAuthenticated(:final identity) => identity.id,
        _ => null,
      };
      return context.mounted && currentPrincipal == principal
          ? arguments
          : null;
    },
  );
  if (!context.mounted) return;
  if (outcome.complete) {
    onComplete();
  } else if (outcome.error case final BeakException error) {
    onError(error);
  }
}

final class _ModelActionButton extends HookWidget {
  const _ModelActionButton({required this.action, required this.onRun});

  final BeakModelAction action;
  final Future<void> Function() onRun;

  @override
  Widget build(BuildContext context) {
    final pending = useState(false);
    return OiButton.secondary(
      label: action.label,
      onTap: pending.value
          ? null
          : () async {
              pending.value = true;
              try {
                await onRun();
              } finally {
                if (context.mounted) pending.value = false;
              }
            },
    );
  }
}

Widget _formScaffold({
  required BeakFormScreen? form,
  required BeakResource resource,
  required OiResourcePageVariant variant,
  required Widget child,
  String? title,
}) => form?.fullScreen == true || (form?.steps.isEmpty ?? true)
    ? child
    : BeakPageScaffold(
        resource: resource,
        variant: variant,
        title: title,
        surface: false,
        child: child,
      );

Widget Function(BuildContext, BeakFormSession, BeakFormMode, Widget, Widget)?
_pageFrame(
  BeakFormScreen? form,
  BeakResource resource,
  OiResourcePageVariant variant,
) {
  if (form?.fullScreen == true || (form?.steps.isNotEmpty ?? false)) {
    return null;
  }
  return (context, session, mode, actions, child) => BeakPageScaffold(
    resource: resource,
    variant: variant,
    surface: false,
    showBack: form?.showBack ?? true,
    padding: form?.pagePadding,
    gap: form?.pageGap,
    title: variant == OiResourcePageVariant.create
        ? BeakLocalizations.of(context).createTitle(resource.effectiveLabel)
        : session.root.snapshot[resource.model.displayColumnKey]?.raw
                  ?.toString() ??
              resource.effectiveLabel,
    actions: [
      if (session.recordId != null)
        for (final action in resource.recordActions)
          if (resource.allowsAction(action) &&
              action.roles.contains(switch (mode) {
                BeakFormMode.read => BeakScreenRole.read,
                BeakFormMode.create => BeakScreenRole.create,
                BeakFormMode.edit => BeakScreenRole.edit,
              }))
            BeakActionButton(
              action: action,
              record: session.root.snapshot,
              actionContext: BeakActionContext(
                buildContext: context,
                model: resource.model,
                dataSource: session.repository.dataSource,
                router: GoRouter.of(context),
                refresh: session.load,
                onError: resource.onActionError,
                canExecute: resource.allowsAction,
              ),
            ),
      actions,
    ],
    heading: form?.recordHeader == null
        ? null
        : BeakRecordTemplateView(
            template: form!.recordHeader!,
            draft: session.root,
            titleVariant: OiLabelVariant.h1,
            subtitleVariant: OiLabelVariant.body,
            inlineBadges: true,
            inlineSubtitle: true,
            titleTrailing:
                mode == BeakFormMode.edit && form.editingLabel != null
                ? OiBadge.soft(
                    label: form.editingLabel!,
                    icon: OiIcons.pencil,
                    color: OiBadgeColor.neutral,
                  )
                : null,
          ),
    child: child,
  );
}

List<BeakTableAction> _presentActions(
  BeakListDefinition? definition,
  List<BeakTableAction> available,
) {
  if (definition == null) return available;
  final presentations =
      definition.rowActions ??
      [for (final action in available) BeakActionPresentation(key: action.id)];
  return [
    ..._configureActionPresentations(presentations, available),
    for (final action in available)
      if (!presentations.any((presentation) => presentation.key == action.id))
        BeakTableAction(
          id: action.id,
          label: action.label,
          semanticLabel: action.semanticLabel,
          placement: BeakActionPlacement.column,
          icon: action.icon,
          destructive: action.destructive,
          visibleWhen: action.visibleWhen,
          onRun: action.onRun,
        ),
  ];
}

List<BeakTableAction> _configureActionPresentations(
  List<BeakActionPresentation> presentations,
  List<BeakTableAction> available,
) => [
  for (final presentation in presentations)
    for (final action in available.where(
      (action) => action.id == presentation.key,
    ))
      BeakTableAction(
        id: action.id,
        label: presentation.label ?? action.label,
        labelValue: presentation.labelValue ?? action.labelValue,
        selectionLabel: presentation.selectionLabel ?? action.selectionLabel,
        semanticLabel: action.semanticLabel ?? action.label,
        placement: presentation.placement,
        icon: presentation.icon ?? action.icon,
        destructive: presentation.destructive ?? action.destructive,
        group: presentation.group ?? action.group,
        visibleWhen: action.visibleWhen,
        onRun: action.onRun,
      ),
];

String _withReturnTo(GoRouter router, String destination) {
  final current = router.routeInformationProvider.value.uri;
  final back = current.queryParameters['returnTo'] ?? current.toString();
  return Uri.parse(
    destination,
  ).replace(queryParameters: {'returnTo': back}).toString();
}

/// Adapts the same authorized commands to the shared floating selection surface.
class _FloatingSelectionBar extends HookWidget {
  const _FloatingSelectionBar({
    required this.actions,
    required this.selection,
    required this.recordNoun,
  });
  final String recordNoun;
  final List<BeakTableAction> actions;
  final BeakTableSelection selection;
  @override
  Widget build(BuildContext context) {
    final pending = useState<String?>(null);
    return OiBulkBar(
      selectedCount: selection.ids.length,
      totalCount: selection.total,
      label: recordNoun,
      compact: true,
      inverse: true,
      showSelectAll: false,
      onDismiss: pending.value == null ? selection.clear : null,
      labels: OiBulkBarLabels(
        selectionCount: (count, _, _) => '$count $recordNoun selected',
      ),
      actions: [
        for (final action in actions)
          OiBulkAction(
            label:
                action.selectionLabel?.call(selection.ids.length) ??
                action.label,
            icon: action.icon ?? OiIcons.play,
            variant: action.destructive
                ? OiBulkActionVariant.destructive
                : OiBulkActionVariant.ghost,
            loading: pending.value == action.id,
            onTap: () async {
              if (pending.value != null) return;
              pending.value = action.id;
              try {
                await action.onRun([...selection.ids]);
              } finally {
                if (context.mounted) pending.value = null;
              }
            },
          ),
      ],
    );
  }
}
