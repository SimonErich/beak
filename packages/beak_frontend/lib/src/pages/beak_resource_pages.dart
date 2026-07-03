import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../actions/beak_action.dart';
import '../actions/beak_action_button.dart';
import '../data/beak_resource_repository.dart';
import '../detail/beak_detail_view.dart';
import '../detail/relation_manager.dart';
import '../filters/beak_filter_widget.dart';
import '../form/beak_data_form.dart';
import '../panel/beak_panel_config.dart';
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

    Future<BeakRecord?> recordOf(Object id) async {
      final result = await BeakResourceRepository(
        dataSource,
      ).getOne(model.table, id);
      return switch (result) {
        BeakOk(:final value) => value,
        BeakErr() => null,
      };
    }

    BeakTableAction rowAction(BeakRecordAction action) => BeakTableAction(
      id: action.key,
      label: action.label,
      icon: action.icon,
      destructive: action.color == BeakColor.error,
      onRun: (ids) async {
        for (final id in ids) {
          final BeakRecord? record = await recordOf(id);
          if (record != null) {
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
        final records = await dataSource.batchGet(model.table, ids);
        await executeBeakAction(
          action: action,
          context: actionContext,
          records: records,
        );
      },
    );

    var spec = BeakQuerySpec(table: model.table);
    if (filter.value case final BeakFilter active) {
      spec = spec.withFilter(active);
    }

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
      filters: resource.filters.isEmpty
          ? null
          : BeakFilterBar(
              filters: resource.filters,
              onChanged: (combined) => filter.value = combined,
            ),
      child: BeakDataTable(
        key: ValueKey((filter.value, generation.value)),
        model: model,
        dataSource: dataSource,
        initialSpec: spec,
        onRowTap: (record) {
          final Object? id = model.primaryKeyOf(record);
          if (id != null) {
            router.go(BeakRoutes.show(model.table, id));
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
      ),
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
        final result = await BeakResourceRepository(
          dataSource,
        ).getOne(model.table, recordId);
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
        (final BeakRecord value, _) => SingleChildScrollView(
          child: OiColumn(
            breakpoint: context.breakpoint,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BeakDetailView(model: model, record: value),
              for (final relationship in model.relationships)
                if (relationship.cardinality == BeakRelationCardinality.many)
                  BeakRelationManager(
                    parentModel: model,
                    parentId: recordId,
                    relationship: relationship,
                    dataSource: dataSource,
                  ),
            ],
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
    super.key,
  });

  /// The resource this page creates records of.
  final BeakResource resource;

  /// The source the form submits through.
  final BeakDataSource dataSource;

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
    super.key,
  });

  /// The resource this page edits a record of.
  final BeakResource resource;

  /// The source the form loads and submits through.
  final BeakDataSource dataSource;

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
        recordId: recordId,
        onSaved: (_) =>
            router.go(BeakRoutes.show(resource.model.table, recordId)),
      ),
    );
  }
}
