import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the faqs resource.
abstract final class FaqColumns {
  /// The owning category.
  static const categoryId = BeakStringColumn(
    key: 'category_id',
    label: 'Category',
    visibleOn: {BeakContext.form},
  );

  /// The question.
  static const question = BeakStringColumn(
    key: 'question',
    label: 'Question',
    searchable: true,
    rules: [BeakRequired(), BeakMaxLength(255)],
  );

  /// The answer.
  static const answer = BeakTextColumn(
    key: 'answer',
    label: 'Answer',
    searchable: true,
    rules: [BeakRequired()],
  );

  /// Whether the question is featured on the landing page.
  static const featured = BeakBoolColumn(
    key: 'featured',
    label: 'Featured',
    filterable: true,
  );

  /// Ordering within the category.
  static const sortIndex = BeakIntColumn(
    key: 'sort_index',
    label: 'Order',
    min: 0,
    sortable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    categoryId,
    question,
    answer,
    featured,
    sortIndex,
  ];
}

/// Typed relationships of the faqs resource.
abstract final class FaqRelations {
  /// The owning category.
  static const category = BeakBelongsTo(
    key: 'category',
    label: 'Category',
    relatedTable: 'faq_categories',
    displayColumnKey: 'name',
    foreignKey: 'category_id',
    searchColumnKeys: ['name'],
  );
}

/// The faqs resource — a help-center question and answer.
final class FaqModel extends BeakModel {
  /// Creates the faqs model.
  const FaqModel();

  @override
  String get table => 'faqs';

  @override
  String get displayColumnKey => 'question';

  @override
  List<BeakColumn> get columns => FaqColumns.values;

  @override
  List<BeakRelationship> get relationships => const [FaqRelations.category];
}
