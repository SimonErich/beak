import 'package:beak_core/beak_core.dart';
import 'package:flutter/foundation.dart' show listEquals, setEquals;
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:signals/signals_flutter.dart';

import '../data/beak_relation_loads.dart';
import '../data/beak_resource_repository.dart';
import '../data/optimistic.dart';
import '../localization/beak_localizations.dart';
import 'beak_table_action.dart';
import 'column_cell_renderer.dart';
import 'beak_table_view_model.dart';
import '../query/beak_query_controller.dart';
import '../presentation/beak_record_template.dart';
import '../presentation/beak_action_presentation.dart';

/// A visible-page selection snapshot; identities retain their model wire type.
final class BeakTableSelection {
  /// Supplied by the table after selection or its current page changes.
  const BeakTableSelection({
    required this.ids,
    required this.total,
    required this.clear,
  });

  /// Selected, currently visible record identities.
  final List<Object> ids;

  /// Records available on this page.
  final int total;

  /// Clears the owning table's selection.
  final VoidCallback clear;
}

/// The generated list view: a model's table-context columns rendered as an
/// `OiTable` with server-side sort/filter/pagination through
/// [BeakQuerySpec], per-row and bulk actions, optimistic delete with undo,
/// and inline edit — zero per-resource table code.
///
/// Every column's cell is drawn by [renderBeakCell] from its table-context
/// render intent, so badges, dates, thumbnails, and custom cells match the
/// detail view exactly. Sort, filter, and page changes rewrite the spec on
/// the internal [BeakTableViewModel] and refetch (latest-wins); a fetch failure
/// renders a retryable error state.
///
/// ```dart
/// BeakDataTable(
///   model: const ProductModel(),
///   dataSource: dataSource,
///   onRowTap: (record) => context.go('/products/${record['id']?.raw}'),
///   actions: [
///     BeakTableAction(
///       id: 'duplicate',
///       label: 'Duplicate',
///       icon: OiIcons.copy,
///       onRun: (ids) async => duplicate(ids.single),
///     ),
///   ],
///   bulkActions: [
///     BeakTableAction(
///       id: 'archive',
///       label: 'Archive',
///       destructive: true,
///       onRun: (ids) async => archiveAll(ids),
///     ),
///   ],
/// )
/// ```
class BeakDataTable extends HookWidget {
  /// Creates the table for [model] over [dataSource].
  ///
  /// [initialSpec] seeds the first query; [controller] injects the table
  /// controller (tests drive selection through it); [enableDelete] adds
  /// the built-in optimistic delete row action; [onRowTap] typically
  /// navigates to the record's show route.
  const BeakDataTable({
    required this.model,
    required this.dataSource,
    this.columns,
    this.fields,
    this.actions = const [],
    this.bulkActions = const [],
    this.onRowTap,
    this.onOpenRelation,
    this.initialSpec,
    this.baseFilter,
    this.controller,
    this.onViewModel,
    this.enableDelete = true,
    this.showHeaderFilters = true,
    this.queryController,
    this.presentations,
    this.showStatusBar = true,
    this.shrinkWrap = false,
    this.rowHeightInPixels,
    this.showBulkActionBar = true,
    this.onSelectionChanged,
    this.pageSizeOptions = const [10, 25, 50, 100],
    super.key,
  });

  /// Observes each owned view model once, for advanced surface integrations.
  /// The table owns disposal; callers must not dispose the supplied instance.
  final ValueChanged<BeakTableViewModel>? onViewModel;

  /// Optional visual row height; null follows the surrounding table theme.
  final double? rowHeightInPixels;

  /// The model this table lists.
  final BeakModel model;

  /// The source queries and mutations run against.
  final BeakDataSource dataSource;

  /// The columns to render, in order; defaults to [model]'s table-context
  /// columns.
  final List<BeakColumn>? columns;

  /// Typed fields to display in order, with related paths loaded automatically.
  /// Related fields are filterable; sorting remains local-column only.
  final List<BeakScalarField<Object>>? fields;

  /// Per-row actions, each invoked with the row's primary key.
  final List<BeakTableAction> actions;

  /// Actions over the selected rows.
  final List<BeakTableAction> bulkActions;

  /// Invoked with the tapped record.
  final void Function(BeakRecord record)? onRowTap;

  /// Invoked with the tapped record on the far side of a to-one relationship
  /// — typically navigating to *that* record's show route.
  ///
  /// When null the relationship still renders its name; it just is not a
  /// link, because a link that goes nowhere is worse than plain text.
  final void Function(BeakRelationship relation, BeakRecord related)?
  onOpenRelation;

  /// The spec the first fetch runs (default: unfiltered first page).
  final BeakQuerySpec? initialSpec;

  /// A persistent predicate outside the table's control (e.g. the filter
  /// bar's); in-table column filters AND-merge with it instead of
  /// replacing it.
  final BeakFilter? baseFilter;

  /// Test seam for driving selection and pagination programmatically.
  final OiTableController? controller;

  /// Whether the built-in optimistic delete action renders.
  final bool enableDelete;

  /// Whether columns expose the table's text header filters.
  ///
  /// Resource pages disable these when their typed filter bar is present, so
  /// an enum select cannot also issue a conflicting text-contains predicate.
  final bool showHeaderFilters;

  /// Shared query from the containing declarative list.
  final BeakQueryController? queryController;

  /// Fits a short visible page without reserving empty viewport space.
  final bool shrinkWrap;

  /// Renders the conventional inline bar; composed pages may place it elsewhere.
  final bool showBulkActionBar;

  /// Reports a page-local selection for advanced composed surfaces.
  final ValueChanged<BeakTableSelection>? onSelectionChanged;

  /// Optional status count above pagination.
  final bool showStatusBar;

  /// Available page lengths; current length is always included.
  final List<int> pageSizeOptions;

  /// Composite columns; fields and model defaults remain supported shorthands.
  final List<BeakTableColumn>? presentations;

  @override
  Widget build(BuildContext context) {
    final strings = BeakLocalizations.of(context);
    final viewModel = useMemoized(
      () => BeakTableViewModel(
        model,
        dataSource,
        // The table renders a column per to-one relationship, so the table is
        // what asks for them — every caller gets names instead of uuids
        // without knowing to request it.
        initial: queryController != null
            ? beakWithFieldLoads(queryController!.query, [
                ...?fields,
                for (final action in actions)
                  ...?action.labelValue?.dependencies,
                for (final column in presentations ?? const <BeakTableColumn>[])
                  ...column.fields,
              ])
            : fields != null
            ? beakWithFieldLoads(
                initialSpec ?? BeakQuerySpec(table: model.table),
                fields!,
              )
            : beakWithToOneLoads(
                initialSpec ?? BeakQuerySpec(table: model.table),
                model,
              ),
        baseFilter: baseFilter,
        queryController: queryController,
        queryFields: [
          ...?fields,
          for (final action in actions) ...?action.labelValue?.dependencies,
          for (final column in presentations ?? const <BeakTableColumn>[])
            ...column.fields,
        ],
      ),
      [
        model,
        dataSource,
        queryController ?? initialSpec,
        baseFilter,
        fields,
        presentations,
        actions
            .expand(
              (action) =>
                  action.labelValue?.dependencies ??
                  const <BeakFieldRef<Object>>[],
            )
            .map((field) => field.qualifiedKey)
            .join(','),
      ],
    );
    // --8<-- [start:viewModelLifecycle]
    useEffect(() {
      onViewModel?.call(viewModel);
      viewModel.refresh();
      return viewModel.dispose;
    }, [viewModel]);
    // --8<-- [end:viewModelLifecycle]

    final tableController = useMemoized(
      () =>
          controller ??
          OiTableController(
            pageSize: viewModel.spec.value.pagination.perPage,
            serverSidePagination: true,
          ),
      [controller, viewModel],
    );

    // Selection lives on the controller (users and tests both drive it
    // there). OiTable notifies the controller during its own build, so the
    // sync into widget state defers to the frame end.
    final selectedKeys = useState(const <String>{});
    useEffect(() {
      var mounted = true;
      var lastIds = const <Object>[];
      var lastTotal = -1;
      void syncSelection() {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || viewModel.isDisposed) return;
          final Set<String> current = {...tableController.selectedRows};
          if (!setEquals(current, selectedKeys.value)) {
            selectedKeys.value = current;
          }
          final rows = viewModel.page.peek()?.items ?? const <BeakRecord>[];
          final ids = [
            for (final row in rows)
              if (model.primaryKeyOf(row) case final Object id)
                if (current.contains(id.toString())) id,
          ];
          if (!listEquals(lastIds, ids) || lastTotal != rows.length) {
            lastIds = ids;
            lastTotal = rows.length;
            onSelectionChanged?.call(
              BeakTableSelection(
                ids: List.unmodifiable(ids),
                total: rows.length,
                clear: () {
                  if (mounted) tableController.clearSelection();
                },
              ),
            );
          }
        });
      }

      tableController.addListener(syncSelection);
      final stop = effect(() {
        viewModel.page.value;
        syncSelection();
      });
      return () {
        mounted = false;
        stop();
        tableController.removeListener(syncSelection);
      };
    }, [tableController, viewModel]);

    Object? idOf(BeakRecord record) => model.primaryKeyOf(record);

    // --8<-- [start:watchPage]
    return Watch.builder(
      builder: (context) {
        final page = viewModel.page.value;
        final rows = page?.items ?? const <BeakRecord>[];
        final int total = page?.total ?? 0;
        // --8<-- [end:watchPage]
        final sort = viewModel.spec.value.sorts.firstOrNull;
        final sortColumn = sort == null
            ? null
            : presentations
                      ?.where((column) => column.sortBy?.key == sort.columnKey)
                      .firstOrNull
                      ?.key ??
                  sort.columnKey;
        if (tableController.sortColumnId != sortColumn ||
            (sort != null &&
                tableController.sortAscending == sort.descending)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted ||
                viewModel.isDisposed ||
                viewModel.spec.value.sorts.firstOrNull != sort) {
              return;
            }
            if (sortColumn == null) {
              tableController.clearSort();
            } else {
              tableController.sortBy(sortColumn, ascending: !sort!.descending);
            }
          });
        }
        final desired = viewModel.spec.value.pagination;
        if (tableController.pagination.pageSize != desired.perPage ||
            tableController.pagination.currentPage != desired.page - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted || viewModel.isDisposed) return;
            tableController.pagination.setPageSize(desired.perPage);
            tableController.pagination.goToPage(desired.page - 1);
          });
        }
        if (tableController.totalRows != total) {
          // The controller notifies its listeners; defer past this build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            tableController.totalRows = total;
          });
        }

        final error = viewModel.error.value;
        if (error != null) {
          return OiEmptyState.error(
            description: strings.errorMessage(error),
            actionLabel: strings.retry,
            onAction: viewModel.refresh,
          );
        }

        return OiColumn(
          breakpoint: context.breakpoint,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
          children: [
            if (showBulkActionBar &&
                bulkActions.isNotEmpty &&
                selectedKeys.value.isNotEmpty)
              _BulkActionBar(
                actions: bulkActions,
                // Raw primary keys, honoring the onRun contract — the
                // controller only knows stringified row keys.
                selectedIds: [
                  for (final record in rows)
                    if (selectedKeys.value.contains(idOf(record)?.toString()))
                      if (idOf(record) case final Object id) id,
                ],
              ),
            // OiTable virtualizes its rows and must own the remaining
            // height.
            Flexible(
              fit: shrinkWrap ? FlexFit.loose : FlexFit.tight,
              child: OiTable<BeakRecord>(
                shrinkWrap: shrinkWrap,
                rowHeight: rowHeightInPixels,
                label: strings.records,
                labels: OiTableLabels(
                  rows: strings.tableRows,
                  rowCount: strings.tableRowCount,
                  selectedCount: strings.selectedCount,
                  columns: strings.tableColumns,
                  manageColumns: strings.tableManageColumns,
                  pagination: OiPaginationLabels(
                    perPage: strings.tablePerPage,
                    navigation: strings.tablePagination,
                    firstPage: strings.tableFirstPage,
                    previousPage: strings.tablePreviousPage,
                    nextPage: strings.tableNextPage,
                    lastPage: strings.tableLastPage,
                    page: strings.tablePage,
                    total: (start, end, total, _) =>
                        strings.tablePageTotal(start, end, total),
                  ),
                ),
                rows: rows,
                controller: tableController,
                columns: _columns(viewModel),
                rowKey: (record) => idOf(record)?.toString() ?? '',
                selectable: bulkActions.isNotEmpty,
                multiSelect: bulkActions.isNotEmpty,
                onRowTap: onRowTap == null
                    ? null
                    : (record, index) {
                        if (!viewModel.isDisposed) onRowTap?.call(record);
                      },
                serverSideSort: true,
                onSort: (columnId, {required ascending}) {
                  final presentation = presentations
                      ?.where((column) => column.key == columnId)
                      .firstOrNull;
                  final column =
                      presentation?.sortBy?.column ??
                      model.columnByKey(columnId);
                  if (column != null) {
                    viewModel.sortBy(column, descending: !ascending);
                  }
                },
                serverSideFilter: true,
                onFilter: (filters) =>
                    viewModel.setFilter(_filterTree(filters)),
                showStatusBar: showStatusBar,
                pageSizeOptions: ({
                  ...pageSizeOptions,
                  viewModel.spec.value.pagination.perPage,
                }.toList()..sort()),
                paginationMode: OiTablePaginationMode.pages,
                totalRows: page?.total ?? 0,
                onPageChange: (zeroBasedPage, pageSize) {
                  final spec = viewModel.spec.value;
                  if (pageSize != spec.pagination.perPage) {
                    viewModel.setPageSize(pageSize);
                  } else if (zeroBasedPage + 1 != spec.pagination.page) {
                    viewModel.goToPage(zeroBasedPage + 1);
                  }
                },
                onCellChanged: (record, rowIndex, columnId, value) {
                  // interop: OiTable delivers edited cell values untyped.
                  _commitCellEdit(viewModel, record, columnId, value);
                },
                loading: viewModel.loading.value,
                emptyState: OiEmptyState(
                  title: strings.noRecords,
                  icon: OiIcons.inbox,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<OiTableColumn<BeakRecord>> _columns(BeakTableViewModel viewModel) {
    // A relationship is shown in place of the foreign key it owns: the key
    // renders as the uuid it stores, which tells the reader nothing, and
    // showing both would be the same fact twice.
    final List<BeakColumn> shown =
        columns ?? model.columnsFor(BeakContext.table);
    final relationsByForeignKey = <String, BeakRelationship>{
      if (fields == null)
        for (final relation in beakToOneRelationsOf(model))
          if (relation is BeakBelongsTo) relation.foreignKey: relation,
    };
    return <OiTableColumn<BeakRecord>>[
      if (presentations case final List<BeakTableColumn> selected)
        for (final column in selected)
          OiTableColumn<BeakRecord>(
            id: column.key,
            header: column.label,
            width: column.widthInPixels,
            minWidth: column.minWidthInPixels,
            textAlign: column.textAlign,
            cellPadding: column.cellPadding,
            sortable:
                column.sortBy != null &&
                column.sortBy!.path.isEmpty &&
                column.sortBy!.column.sortable,
            filterable: false,
            cellBuilder: (context, record, rowIndex) => column.template == null
                ? _configuredAction(column, record)
                : BeakRecordTemplateView(
                    template: column.template!,
                    record: record,
                  ),
          ),
      if ((presentations, fields) case (
        null,
        final List<BeakScalarField<Object>> selected,
      ))
        for (final field in selected)
          OiTableColumn<BeakRecord>(
            id: field.qualifiedKey,
            header: field.label,
            minWidth: 160,
            sortable: field.path.isEmpty && field.column.sortable,
            filterable: showHeaderFilters && field.column.filterable,
            valueGetter: (record) => field.readFrom(record)?.toString() ?? '',
            cellBuilder: (context, record, rowIndex) =>
                renderBeakField(context, field: field, record: record),
          ),
      if (fields == null && presentations == null)
        for (final column in shown)
          if (relationsByForeignKey[column.key] case final BeakRelationship r)
            _relationColumn(r)
          else
            OiTableColumn<BeakRecord>(
              id: column.key,
              header: column.label,
              minWidth: 160,
              sortable: column.sortable,
              filterable: showHeaderFilters && column.filterable,
              valueGetter: (record) =>
                  record[column.key]?.raw?.toString() ?? '',
              cellBuilder: (context, record, rowIndex) =>
                  renderBeakCell(context, column: column, record: record),
            ),
      // A to-one whose key is hidden from the table context still deserves a
      // column — the relationship is what the reader came for.
      if (fields == null && presentations == null)
        for (final relation in beakToOneRelationsOf(model))
          if (relation is! BeakBelongsTo ||
              !shown.any((column) => column.key == relation.foreignKey))
            _relationColumn(relation),
      if (actions.any(
            (action) => action.placement != BeakActionPlacement.column,
          ) ||
          enableDelete)
        OiTableColumn<BeakRecord>(
          id: '_actions',
          header: '',
          cellPadding: const EdgeInsets.symmetric(horizontal: 4),
          minWidth: 40,
          width:
              8.0 +
              (enableDelete ? 32 : 0) +
              (actions.any(
                    (action) =>
                        action.placement == BeakActionPlacement.overflow,
                  )
                  ? 32
                  : 0) +
              actions.fold<double>(
                0,
                (width, action) =>
                    width +
                    switch (action.placement) {
                      BeakActionPlacement.primary => 140,
                      BeakActionPlacement.icon => 44,
                      BeakActionPlacement.overflow => 0,
                      BeakActionPlacement.column => 0,
                    },
              ),
          sortable: false,
          filterable: false,
          resizable: false,
          cellBuilder: (context, record, rowIndex) =>
              _rowActions(context, viewModel, record),
        ),
    ];
  }

  Widget _configuredAction(BeakTableColumn column, BeakRecord record) {
    final selection = column.actionSelector?.readFrom(record);
    final presentation =
        column.actionChoices[selection] ?? column.fallbackAction;
    if (presentation == null) return const SizedBox.shrink();
    final available = actions
        .where(
          (action) =>
              action.id == presentation.key &&
              (action.visibleWhen?.call(record) ?? true),
        )
        .firstOrNull;
    if (available == null) return const SizedBox.shrink();
    final id = model.primaryKeyOf(record);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: _RowActionButton(
        key: ValueKey((column.key, id, available.id)),
        recordId: id,
        constrained: true,
        action: BeakTableAction(
          id: available.id,
          label: presentation.label ?? available.label,
          semanticLabel: available.semanticLabel ?? available.label,
          onRun: available.onRun,
          icon: available.icon,
          destructive: available.destructive,
          placement: BeakActionPlacement.primary,
        ),
      ),
    );
  }

  /// The column showing the record on the far side of [relation].
  ///
  /// Reads the eager-loaded record the page asked for, so the cell is exact
  /// and costs nothing: the whole page is one query. A row whose relation was
  /// not loaded — or whose foreign key is null — renders empty rather than
  /// guessing.
  OiTableColumn<BeakRecord> _relationColumn(BeakRelationship relation) =>
      OiTableColumn<BeakRecord>(
        id: relation.key,
        header: relation.label,
        minWidth: 160,
        sortable: false,
        filterable: false,
        valueGetter: (record) => _relationLabelOf(relation, record),
        cellBuilder: (context, record, rowIndex) {
          final BeakRecord? related = _relatedOf(relation, record);
          if (related == null) {
            return const OiLabel.body('');
          }
          final String label = relation.displayLabelOf(related);
          if (onOpenRelation == null) {
            return OiLabel.body(label, maxLines: 1);
          }
          return GestureDetector(
            onTap: () => onOpenRelation?.call(relation, related),
            child: OiLabel.link(label, maxLines: 1),
          );
        },
      );

  /// The display label of the record [relation] points at, or empty.
  static String _relationLabelOf(BeakRelationship relation, BeakRecord record) {
    final BeakRecord? related = _relatedOf(relation, record);
    return related == null ? '' : relation.displayLabelOf(related);
  }

  /// The eager-loaded record [relation] points at, or null when the foreign
  /// key is null or the relation was not loaded.
  static BeakRecord? _relatedOf(BeakRelationship relation, BeakRecord record) {
    final List<BeakRecord> related = record.relations[relation.key] ?? const [];
    return related.isEmpty ? null : related.first;
  }

  Widget _rowActions(
    BuildContext context,
    BeakTableViewModel viewModel,
    BeakRecord record,
  ) {
    final Object? id = model.primaryKeyOf(record);
    return OiRow(
      breakpoint: context.breakpoint,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (final action in actions.where(
          (action) =>
              action.placement == BeakActionPlacement.icon ||
              action.placement == BeakActionPlacement.primary,
        ))
          if (action.visibleWhen?.call(record) ?? true)
            _RowActionButton(
              key: ValueKey((id, action.id)),
              action: action,
              recordId: id,
            ),
        if (actions.any(
          (action) =>
              action.placement == BeakActionPlacement.overflow &&
              (action.visibleWhen?.call(record) ?? true),
        ))
          _RowOverflowActions(
            recordId: id,
            record: record,
            actions: [
              for (final action in actions)
                if (action.placement == BeakActionPlacement.overflow &&
                    (action.visibleWhen?.call(record) ?? true))
                  action,
            ],
          ),
        if (enableDelete)
          OiButton.icon(
            size: OiButtonSize.small,
            icon: OiIcons.trash2,
            label: BeakLocalizations.of(context).delete,
            onTap: id == null
                ? null
                : () => _deleteOptimistically(context, viewModel, id),
          ),
      ],
    );
  }

  void _deleteOptimistically(
    BuildContext context,
    BeakTableViewModel viewModel,
    Object id,
  ) {
    ({BeakRecord record, int index})? removed;
    BeakOptimistic.mutate(
      context,
      apply: () => removed = viewModel.removeLocally(id),
      rollback: () {
        final ({BeakRecord record, int index})? toRestore = removed;
        if (toRestore != null) {
          viewModel.insertLocally(toRestore.record, toRestore.index);
        }
      },
      commit: () => dataSource.delete(model.table, id),
      message: BeakLocalizations.of(context).recordDeleted,
    );
  }

  Future<void> _commitCellEdit(
    BeakTableViewModel viewModel,
    BeakRecord record,
    String columnId,
    Object? editedValue,
  ) async {
    final column = model.columnByKey(columnId);
    final Object? id = model.primaryKeyOf(record);
    if (column == null || id == null) {
      return;
    }
    final BeakValue typed = _coerceEdited(column, editedValue);
    final updated = BeakRecord(
      values: {...record.values, columnId: typed},
      relations: record.relations,
    );
    final previous = viewModel.replaceRecordLocally(id, updated);
    final result = await BeakResourceRepository(
      dataSource,
    ).update(model.table, id, BeakRecord(values: {columnId: typed}));
    if (result case BeakErr() when previous != null) {
      viewModel.replaceRecordLocally(id, previous);
    }
  }

  /// Coerces an inline-edited string back to the column's value type.
  BeakValue _coerceEdited(BeakColumn column, Object? editedValue) {
    final String text = editedValue?.toString() ?? '';
    return switch (column) {
      BeakIntColumn() => switch (int.tryParse(text)) {
        final int number => BeakIntValue(number),
        null => BeakStringValue(text),
      },
      BeakDecimalColumn() => switch (double.tryParse(text)) {
        final double number => BeakDoubleValue(number),
        null => BeakStringValue(text),
      },
      BeakBoolColumn() => BeakBoolValue(text == 'true'),
      _ => BeakStringValue(text),
    };
  }

  BeakFilter? _filterTree(Map<String, String> filters) {
    final leaves = <BeakFilter>[
      for (final MapEntry(:key, :value) in filters.entries)
        if (value.trim().isNotEmpty &&
            (model.columnByKey(key) != null ||
                (fields?.any((field) => field.qualifiedKey == key) ?? false)))
          BeakFieldFilter.forKey(
            key,
            BeakOperator.contains,
            BeakStringValue(value.trim()),
          ),
    ];
    return BeakFilter.allOf(leaves);
  }
}

/// Keeps a row action pending until its confirmation and mutation finish.
final class _RowActionButton extends HookWidget {
  const _RowActionButton({
    required this.action,
    this.recordId,
    this.constrained = false,
    super.key,
  });

  final bool constrained;

  final BeakTableAction action;
  final Object? recordId;

  @override
  Widget build(BuildContext context) {
    final pending = useState(false);
    final id = recordId;
    Future<void> run() async {
      if (pending.value || id == null) return;
      pending.value = true;
      try {
        await action.onRun([id]);
      } finally {
        if (context.mounted) pending.value = false;
      }
    }

    if (action.placement == BeakActionPlacement.primary) {
      return OiButton.secondary(
        size: OiButtonSize.small,
        label: action.label,
        semanticLabel: action.semanticLabel,
        tooltip: action.semanticLabel != action.label
            ? action.semanticLabel
            : null,
        fullWidth: false,
        loading: pending.value,
        onTap: id == null || pending.value ? null : run,
      );
    }
    return OiButton.icon(
      size: OiButtonSize.small,
      icon: action.icon ?? OiIcons.play,
      label: action.label,
      onTap: id == null || pending.value ? null : run,
    );
  }
}

/// The bulk-action bar shown above the table while rows are selected.
final class _BulkActionBar extends StatelessWidget {
  const _BulkActionBar({required this.actions, required this.selectedIds});

  final List<BeakTableAction> actions;
  final List<Object> selectedIds;

  @override
  Widget build(BuildContext context) => OiRow(
    breakpoint: context.breakpoint,
    gap: const OiResponsive<double>(8),
    children: [
      OiLabel.smallStrong(
        BeakLocalizations.of(context).selectedCount(selectedIds.length),
      ),
      for (final action in actions)
        if (action.destructive)
          OiButton.destructive(
            label: action.label,
            onTap: () => action.onRun([...selectedIds]),
          )
        else
          OiButton.secondary(
            label: action.label,
            onTap: () => action.onRun([...selectedIds]),
          ),
    ],
  );
}

class _RowOverflowActions extends HookWidget {
  const _RowOverflowActions({
    required this.recordId,
    required this.record,
    required this.actions,
  });
  final BeakRecord record;
  final Object? recordId;
  final List<BeakTableAction> actions;
  @override
  Widget build(BuildContext context) {
    final pending = useState(false);
    return OiActionBar(
      label: 'Record actions',
      separator: true,
      overflowIcon: OiIcons.ellipsis,
      size: OiButtonSize.small,
      actions: const [],
      overflowActions: [
        for (final action in actions)
          OiActionBarItem(
            icon: action.icon ?? OiIcons.play,
            label: action.labelValue?.readFrom(record) ?? action.label,
            semanticLabel: action.labelValue?.readFrom(record) ?? action.label,
            group: action.group,
            variant: action.destructive
                ? OiButtonVariant.destructive
                : OiButtonVariant.ghost,
            enabled: recordId != null && !pending.value,
            onTap: () async {
              if (pending.value || recordId == null) return;
              pending.value = true;
              try {
                await action.onRun([recordId!]);
              } finally {
                if (context.mounted) pending.value = false;
              }
            },
          ),
      ],
    );
  }
}
