import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'faq_category.dart';

part 'faq.beak.dart';

/// The faqs resource — a help-center question and answer.
@Resource()
final class Faq extends BeakSchema {
  /// The owning category.
  @BelongsTo()
  late final FaqCategory? category;

  /// The question.
  @Display()
  @Column(searchable: true, rules: [BeakMaxLength(255)])
  late final String question;

  /// The answer.
  @Column(searchable: true)
  late final BeakText answer;

  /// Whether the question is featured on the landing page.
  @Column(filterable: true)
  late final bool? featured;

  /// Ordering within the category.
  @Column(label: 'Order', min: 0, sortable: true)
  late final int? sortIndex;
}
