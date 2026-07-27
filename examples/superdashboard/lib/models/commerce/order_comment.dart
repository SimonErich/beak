import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the order-comments resource — an internal or
/// customer-facing note on an order.
abstract final class OrderCommentColumns {
  /// The comment text.
  static const body = BeakTextColumn(
    key: 'body',
    label: 'Comment',
    searchable: true,
    rules: [BeakRequired()],
  );

  /// Whether the note is internal (staff-only) or customer-visible.
  static const isInternal = BeakBoolColumn(
    key: 'is_internal',
    label: 'Internal',
  );

  /// The author's display name (denormalized for quick reads).
  static const authorName = BeakStringColumn(
    key: 'author_name',
    label: 'Author',
    searchable: true,
  );

  /// When the comment was written.
  static const createdAt = BeakDateTimeColumn(
    key: 'created_at',
    label: 'When',
    sortable: true,
  );

  /// The owning order.
  static const orderId = BeakStringColumn(
    key: 'order_id',
    label: 'Order',
    visibleOn: {BeakContext.form},
  );

  /// The authoring user.
  static const authorId = BeakStringColumn(
    key: 'author_id',
    label: 'Author',
    visibleOn: {BeakContext.form},
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    body,
    isInternal,
    authorName,
    createdAt,
    orderId,
    authorId,
  ];
}

/// Typed relationships of the order-comments resource.
abstract final class OrderCommentRelations {
  /// The owning order.
  static const order = BeakBelongsTo(
    key: 'order',
    label: 'Order',
    relatedTable: 'orders',
    displayColumnKey: 'reference',
    foreignKey: 'order_id',
    searchColumnKeys: ['reference'],
  );

  /// The authoring user.
  static const author = BeakBelongsTo(
    key: 'author',
    label: 'Author',
    relatedTable: 'users',
    displayColumnKey: 'name',
    foreignKey: 'author_id',
    searchColumnKeys: ['name'],
  );
}

/// The order-comments resource — an internal or customer-facing note.
final class OrderCommentModel extends BeakModel {
  /// Creates the order-comments model.
  const OrderCommentModel();

  @override
  String get table => 'order_comments';

  @override
  String get displayColumnKey => 'body';

  @override
  List<BeakColumn> get columns => OrderCommentColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    OrderCommentRelations.order,
    OrderCommentRelations.author,
  ];
}
