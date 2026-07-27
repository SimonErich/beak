import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the faq-categories resource.
abstract final class FaqCategoryColumns {
  /// Category name.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    rules: [BeakRequired(), BeakMaxLength(60)],
  );

  /// Icon name.
  static const icon = BeakStringColumn(
    key: 'icon',
    label: 'Icon',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// Category description.
  static const description = BeakTextColumn(
    key: 'description',
    label: 'Description',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// Ordering.
  static const sortIndex = BeakIntColumn(
    key: 'sort_index',
    label: 'Order',
    min: 0,
    sortable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    name,
    icon,
    description,
    sortIndex,
  ];
}

/// Typed relationships of the faq-categories resource.
abstract final class FaqCategoryRelations {
  /// The questions in this category.
  static const faqs = BeakHasMany(
    key: 'faqs',
    label: 'Questions',
    relatedTable: 'faqs',
    displayColumnKey: 'question',
    foreignKey: 'category_id',
  );
}

/// The faq-categories resource — help-center topic groups.
final class FaqCategoryModel extends BeakModel {
  /// Creates the faq-categories model.
  const FaqCategoryModel();

  @override
  String get table => 'faq_categories';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => FaqCategoryColumns.values;

  @override
  List<BeakRelationship> get relationships => const [FaqCategoryRelations.faqs];
}
