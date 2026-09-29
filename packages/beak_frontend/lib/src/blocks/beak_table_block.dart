part of 'beak_block.dart';

/// A composable data table bound to a model: an order-status, top-users or
/// latest-transactions card, or any other embedded listing.
///
/// Reuses the full `BeakDataTable` (server-side sort, filter, pagination,
/// row actions), so a table on a page behaves exactly like a resource list.
/// [initialSpec] seeds ordering and page size; [baseFilter] scopes the rows;
/// [fields] selects the exact visible fields and their relationship loads;
/// [columns] retains the conventional automatic relationship columns.
///
/// ```dart
/// BeakTableBlock(
///   title: 'Upcoming deliveries',
///   model: const OrderModel(),
///   fields: [
///     OrderModel.reference,
///     OrderModel.status,
///     OrderModel.deliveryDate,
///   ],
///   enableDelete: false,
///   initialSpec: const OrderModel()
///       .query()
///       .orderBy(OrderModel.deliveryDate)
///       .paginate(perPage: 5),
///   baseFilter: OrderModel.status.notEq(OrderStatus.cancelled),
/// );
/// ```
final class BeakTableBlock extends BeakBlock {
  /// Creates a table block over [model].
  const BeakTableBlock({
    required this.model,
    this.title,
    this.columns,
    this.fields,
    this.enableDelete = true,
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
  /// A card on a page is not a list page: three columns read at a glance
  /// where seventeen do not fit at all.
  final List<BeakColumn>? columns;

  /// Exact ordered fields, including typed relationship paths and formatting.
  /// Takes precedence over [columns] and suppresses automatic relation columns.
  final List<BeakScalarField<Object>>? fields;

  /// Adds the built-in delete action. Disable for read-only embedded listings.
  /// Custom [actions] remain available independently.
  final bool enableDelete;

  /// Seeds sort order and page size on first load.
  final BeakQuerySpec? initialSpec;

  /// A filter AND-merged into every query (e.g. status scope).
  final BeakFilter? baseFilter;

  /// Extra per-row actions.
  final List<BeakTableAction> actions;

  /// Invoked when a row is tapped.
  final void Function(BeakRecord record)? onRowTap;
}
