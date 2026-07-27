import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../actions/beak_action.dart';
import '../actions/beak_action_button.dart';
import '../blocks/beak_block_host.dart';
import '../data/beak_relation_loads.dart';
import '../data/beak_resource_repository.dart';
import '../data/reference_cache.dart';
import '../detail/beak_detail_view.dart';
import '../detail/beak_record_scope.dart';
import '../detail/relation_manager.dart';
import '../filters/beak_filter_widget.dart';
import '../form/beak_data_form.dart';
import '../panel/beak_panel_config.dart';
import '../panel/beak_resource_view.dart';
import '../panel/beak_routes.dart';
import '../table/beak_data_table.dart';
import '../table/beak_table_action.dart';
import 'beak_page_scaffold.dart';

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
    final BeakModel model = resource.model;
    final GoRouter router = GoRouter.of(context);
    final actionContext = BeakActionContext(
      buildContext: context,
      model: model,
      dataSource: dataSource,
      router: router,
      refresh: () async => generation.value += 1,
    );

    final repository = BeakResourceRepository(dataSource);

    Future<List<BeakRecord>> recordsOf(List<Object> ids) async =>
        switch (await repository.batchGet(model.table, ids)) {
          BeakOk(:final value) => value,
          BeakErr() => const [],
        };

    BeakTableAction rowAction(BeakRecordAction action) => BeakTableAction(
      id: action.key,
      label: action.label,
      icon: action.icon,
      destructive: action.color == BeakColor.error,
      onRun: (ids) async {
        // The built-in view/edit actions only navigate by id — the row
        // already rendered from the full record, so re-fetching it before
        // dispatch would be a wasted round-trip.
        switch (action) {
          case BeakViewAction():
            for (final id in ids) {
              router.go(BeakRoutes.show(model.table, id));
            }
          case BeakEditAction():
            for (final id in ids) {
              router.go(BeakRoutes.edit(model.table, id));
            }
          default:
            for (final record in await recordsOf(ids)) {
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
      onRun: (ids) async => executeBeakAction(
        action: action,
        context: actionContext,
        records: await recordsOf(ids),
      ),
    );

    var spec = BeakQuerySpec(table: model.table);
    if (filter.value case final BeakFilter active) {
      spec = spec.withFilter(active);
    }

    final Widget table = BeakDataTable(
      key: ValueKey((filter.value, generation.value)),
      model: model,
      dataSource: dataSource,
      initialSpec: spec,
      baseFilter: filter.value,
      onRowTap: (record) {
        final Object? id = model.primaryKeyOf(record);
        if (id != null) {
          router.go(BeakRoutes.show(model.table, id));
        }
      },
      onOpenRelation: (relation, related) {
        final Object? id = related['id']?.raw;
        if (id != null) {
          router.go(BeakRoutes.show(relation.relatedTable, id));
        }
      },
      actions: [
        rowAction(const BeakViewAction()),
        rowAction(const BeakEditAction()),
        for (final action in resource.recordActions) rowAction(action),
      ],
      bulkActions: [
        for (final action in resource.bulkActions) bulkAction(action),
      ],
    );

    return BeakPageScaffold(
      resource: resource,
      variant: OiResourcePageVariant.list,
      actions: [
        for (final action in resource.globalActions)
          BeakActionButton(action: action, actionContext: actionContext),
        BeakActionButton(
          action: const BeakCreateAction(),
          actionContext: actionContext,
        ),
      ],
      filters: switch (resource.effectiveFilters) {
        [] => null,
        final List<BeakFilterDef> active => BeakFilterBar(
          filters: active,
          onChanged: (combined) => filter.value = combined,
        ),
      },
      child: resource.viewModes.length <= 1
          ? table
          : _ViewModeSwitcher(
              viewModes: resource.viewModes,
              model: model,
              table: table,
            ),
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

/// The generated show page: the record rendered through [BeakDetailView],
/// its to-many relations through [BeakRelationManager], with edit/delete
/// actions.
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
    final BeakModel model = resource.model;
    final record = useState<BeakRecord?>(null);
    final failure = useState<BeakException?>(null);
    useEffect(() {
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
    }, [dataSource, recordId]);

    final actionContext = BeakActionContext(
      buildContext: context,
      model: model,
      dataSource: dataSource,
      router: GoRouter.of(context),
    );

    final BeakRecord? loaded = record.value;
    return BeakPageScaffold(
      resource: resource,
      variant: OiResourcePageVariant.show,
      title: '${resource.effectiveLabel} $recordId',
      actions: [
        if (loaded != null) ...[
          BeakActionButton(
            action: const BeakEditAction(),
            actionContext: actionContext,
            record: loaded,
          ),
          BeakActionButton(
            action: const BeakDeleteAction(),
            actionContext: actionContext,
            record: loaded,
          ),
        ],
      ],
      child: switch ((loaded, failure.value)) {
        (null, null) => const OiLabel.body('Loading…'),
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
            child: BeakBlockHost(block: resource.effectiveDetail),
          ),
        ),
      },
    );
  }
}

/// The generated create page: a [BeakDataForm] in create mode that
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
    return BeakPageScaffold(
      resource: resource,
      variant: OiResourcePageVariant.create,
      title: 'Create ${resource.effectiveLabel}',
      child: BeakDataForm(
        model: resource.model,
        dataSource: dataSource,
        referenceCache: referenceCache,
        steps: resource.formSteps,
        layout: resource.formLayout,
        onSaved: (_) => router.go(BeakRoutes.list(resource.model.table)),
      ),
    );
  }
}

/// The generated edit page: a [BeakDataForm] prefilled from `getOne` that
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
    return BeakPageScaffold(
      resource: resource,
      variant: OiResourcePageVariant.edit,
      title: 'Edit ${resource.effectiveLabel} $recordId',
      child: BeakDataForm(
        model: resource.model,
        dataSource: dataSource,
        referenceCache: referenceCache,
        recordId: recordId,
        steps: resource.formSteps,
        layout: resource.formLayout,
        onSaved: (_) =>
            router.go(BeakRoutes.show(resource.model.table, recordId)),
      ),
    );
  }
}
