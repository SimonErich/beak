part of 'beak_block.dart';

/// A composable data table bound to a model — the dashboard's
/// order-status / top-users / latest-transactions tables and any embedded
/// listing.
///
/// Reuses the full `BeakDataTable` (server-side sort, filter, pagination,
/// row actions), so a table on a page behaves exactly like a resource list.
/// [initialSpec] seeds ordering and page size; [baseFilter] scopes the rows;
/// [columns] narrows what is shown, for a table inside a card.
///
/// ```dart
/// BeakTableBlock(
///   title: 'Latest transactions',
///   model: TransactionModel(),
///   initialSpec: BeakQuerySpec(
///     table: 'transactions',
///     sort: BeakSort(column: 'occurred_at', descending: true),
///     pagination: BeakPagination(perPage: 5),
///   ),
/// );
/// ```
final class BeakTableBlock extends BeakBlock {
  /// Creates a table block over [model].
  const BeakTableBlock({
    required this.model,
    this.title,
    this.columns,
    this.initialSpec,
    this.baseFilter,
    this.actions = const [],
    this.onRowTap,
    this.heightInPixels = 360,
    super.span,
  });

  /// Optional heading shown above the table.
  final String? title;

  /// Bounded render height, so the table lays out inside a grid cell or
  /// card (which otherwise impose no vertical bound).
  final double heightInPixels;

  /// The model whose rows the table lists.
  final BeakModel model;

  /// The columns to show, in order; defaults to the model's table-context
  /// columns.
  ///
  /// A dashboard card is not a list page: three columns read at a glance
  /// where seventeen do not fit at all.
  final List<BeakColumn>? columns;

  /// Seeds sort order and page size on first load.
  final BeakQuerySpec? initialSpec;

  /// A filter AND-merged into every query (e.g. status scope).
  final BeakFilter? baseFilter;

  /// Extra per-row actions.
  final List<BeakTableAction> actions;

  /// Invoked when a row is tapped.
  final void Function(BeakRecord record)? onRowTap;
}
