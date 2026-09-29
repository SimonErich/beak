import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'faq.beak.dart';

/// A question visitors ask, drawn by the FAQ block.
@Resource()
final class Faq extends BeakSchema {
  /// The question.
  @Display()
  @Column(searchable: true)
  late final String question;

  /// The answer.
  late final BeakText answer;

  /// The section it is filed under.
  @Column(filterable: true)
  late final String category;

  /// The display order.
  @Column(sortable: true, defaultValue: 0)
  late final int position;
}
