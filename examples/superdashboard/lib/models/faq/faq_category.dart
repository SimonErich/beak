import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'faq.dart';

part 'faq_category.beak.dart';

/// The faq-categories resource — help-center topic groups.
@Resource()
final class FaqCategory extends BeakSchema {
  /// Category name.
  @Display()
  @Column(searchable: true, rules: [BeakMaxLength(60)])
  late final String name;

  /// Icon name.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final String? icon;

  /// Category description.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? description;

  /// Ordering.
  @Column(label: 'Order', min: 0, sortable: true)
  late final int? sortIndex;

  /// The questions in this category.
  @HasMany(label: 'Questions', foreignKey: 'category_id')
  late final List<Faq> faqs;
}
