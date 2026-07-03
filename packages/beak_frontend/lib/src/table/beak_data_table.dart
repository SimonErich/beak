import 'package:beak_core/beak_core.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:signals/signals_flutter.dart';

import '../data/beak_resource_repository.dart';
import '../data/optimistic.dart';
import 'beak_table_action.dart';
import 'column_cell_renderer.dart';
import 'table_view_model.dart';

/// The generated list view: a model's table-context columns rendered as an
/// `OiTable` with server-side sort/filter/pagination through
/// [BeakQuerySpec], per-row and bulk actions, optimistic delete with undo,
/// and inline edit — zero per-resource table code.
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
    this.actions = const [],
    this.bulkActions = const [],
    this.onRowTap,
    this.initialSpec,
    this.controller,
    this.enableDelete = true,
    super.key,
  });

  /// The model this table lists.
  final BeakModel model;

  /// The source queries and mutations run against.
  final BeakDataSource dataSource;

  /// Per-row actions, each invoked with the row's primary key.
  final List<BeakTableAction> actions;

  /// Actions over the selected rows.
  final List<BeakTableAction> bulkActions;

  /// Invoked with the tapped record.
  final void Function(BeakRecord record)? onRowTap;

  /// The spec the first fetch runs (default: unfiltered first page).
  final BeakQuerySpec? initialSpec;

  /// Test seam for driving selection and pagination programmatically.
  final OiTableController? controller;

  /// Whether the built-in optimistic delete action renders.
  final bool enableDelete;

  @override
  Widget build(BuildContext context) {
    final viewModel = useMemoized(
      () => TableViewModel(model, dataSource, initial: initialSpec),
      [model, dataSource, initialSpec],
    );
    useEffect(() {
      viewModel.refresh();
      return viewModel.dispose;
    }, [viewModel]);

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
      void syncSelection() {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final Set<String> current = {...tableController.selectedRows};
          if (!setEquals(current, selectedKeys.value)) {
            selectedKeys.value = current;
          }
        });
      }

      tableController.addListener(syncSelection);
      return () => tableController.removeListener(syncSelection);
    }, [tableController]);

    Object? idOf(BeakRecord record) => model.primaryKeyOf(record);

    return SignalBuilder(
      builder: (context) {
        final page = viewModel.page.value;
        final rows = page?.items ?? const <BeakRecord>[];
        final int total = page?.total ?? 0;
        if (tableController.totalRows != total) {
          // The controller notifies its listeners; defer past this build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            tableController.totalRows = total;
          });
        }

        final error = viewModel.error.value;
        if (error != null) {
          return OiEmptyState.error(
            description: error.message,
            actionLabel: 'Retry',
            onAction: viewModel.refresh,
          );
        }

        return OiColumn(
          breakpoint: context.breakpoint,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.max,
          children: [
            if (bulkActions.isNotEmpty && selectedKeys.value.isNotEmpty)
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
            Expanded(
              child: OiTable<BeakRecord>(
                label: model.table,
                rows: rows,
                controller: tableController,
                columns: _columns(viewModel),
                rowKey: (record) => idOf(record)?.toString() ?? '',
                selectable: bulkActions.isNotEmpty,
                multiSelect: bulkActions.isNotEmpty,
                onRowTap: onRowTap == null
                    ? null
                    : (record, index) => onRowTap?.call(record),
                serverSideSort: true,
                onSort: (columnId, {required ascending}) {
                  final column = model.columnByKey(columnId);
                  if (column != null) {
                    viewModel.sortBy(column, descending: !ascending);
                  }
                },
                serverSideFilter: true,
                onFilter: (filters) =>
                    viewModel.setFilter(_filterTree(filters)),
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
                  title: 'No ${model.table} yet',
                  icon: OiIcons.inbox,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<OiTableColumn<BeakRecord>> _columns(TableViewModel viewModel) => [
    for (final column in model.columnsFor(BeakContext.table))
      OiTableColumn<BeakRecord>(
        id: column.key,
        header: column.label,
        sortable: column.sortable,
        filterable: column.filterable,
        valueGetter: (record) => record[column.key]?.raw?.toString() ?? '',
        cellBuilder: (context, record, rowIndex) =>
            renderBeakCell(context, column: column, record: record),
      ),
    if (actions.isNotEmpty || enableDelete)
      OiTableColumn<BeakRecord>(
        id: '_actions',
        header: '',
        width: 56.0 + 44.0 * actions.length,
        sortable: false,
        filterable: false,
        resizable: false,
        cellBuilder: (context, record, rowIndex) =>
            _rowActions(context, viewModel, record),
      ),
  ];

  Widget _rowActions(
    BuildContext context,
    TableViewModel viewModel,
    BeakRecord record,
  ) {
    final Object? id = model.primaryKeyOf(record);
    return OiRow(
      breakpoint: context.breakpoint,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (final action in actions)
          OiButton.icon(
            icon: action.icon ?? OiIcons.play,
            label: action.label,
            onTap: id == null ? null : () => action.onRun([id]),
          ),
        if (enableDelete)
          OiButton.icon(
            icon: OiIcons.trash2,
            label: 'Delete',
            onTap: id == null
                ? null
                : () => _deleteOptimistically(context, viewModel, id),
          ),
      ],
    );
  }

  void _deleteOptimistically(
    BuildContext context,
    TableViewModel viewModel,
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
      message: 'Record deleted',
    );
  }

  Future<void> _commitCellEdit(
    TableViewModel viewModel,
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
        if (value.trim().isNotEmpty && model.columnByKey(key) != null)
          BeakFieldFilter.forKey(
            key,
            BeakOperator.contains,
            BeakStringValue(value.trim()),
          ),
    ];
    return BeakFilter.allOf(leaves);
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
      OiLabel.smallStrong('${selectedIds.length} selected'),
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
