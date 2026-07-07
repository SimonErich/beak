import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the product-reviews resource — a customer rating and
/// write-up of a product.
abstract final class ProductReviewColumns {
  /// Star rating, 1–5.
  static const rating = BeakIntColumn(
    key: 'rating',
    label: 'Rating',
    min: 1,
    max: 5,
    sortable: true,
    rules: [BeakRequired(), BeakMin(1), BeakMax(5)],
  );

  /// Review headline.
  static const title = BeakStringColumn(
    key: 'title',
    label: 'Title',
    searchable: true,
    rules: [BeakRequired(), BeakMaxLength(160)],
  );

  /// Review body.
  static const body = BeakTextColumn(key: 'body', label: 'Review');

  /// The reviewer's display name (denormalized for quick reads).
  static const authorName = BeakStringColumn(
    key: 'author_name',
    label: 'Reviewer',
    searchable: true,
  );

  /// When the review was written.
  static const createdAt = BeakDateTimeColumn(
    key: 'created_at',
    label: 'Written',
    sortable: true,
  );

  /// The reviewed product.
  static const productId = BeakStringColumn(
    key: 'product_id',
    label: 'Product',
    visibleOn: {BeakContext.form},
  );

  /// The reviewing user.
  static const userId = BeakStringColumn(
    key: 'user_id',
    label: 'User',
    visibleOn: {BeakContext.form},
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    rating,
    title,
    body,
    authorName,
    createdAt,
    productId,
    userId,
  ];
}

/// Typed relationships of the product-reviews resource.
abstract final class ProductReviewRelations {
  /// The reviewed product.
  static const product = BeakBelongsTo(
    key: 'product',
    label: 'Product',
    relatedTable: 'products',
    displayColumnKey: 'name',
    foreignKey: 'product_id',
    searchColumnKeys: ['name'],
  );

  /// The reviewing user.
  static const user = BeakBelongsTo(
    key: 'user',
    label: 'User',
    relatedTable: 'users',
    displayColumnKey: 'name',
    foreignKey: 'user_id',
    searchColumnKeys: ['name'],
  );
}

/// The product-reviews resource — a customer rating and write-up.
final class ProductReviewModel extends BeakModel {
  /// Creates the product-reviews model.
  const ProductReviewModel();

  @override
  String get table => 'product_reviews';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => ProductReviewColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    ProductReviewRelations.product,
    ProductReviewRelations.user,
  ];
}
