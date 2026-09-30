part of 'beak_block.dart';

/// A data-bound FAQ / help center: a model's records rendered on
/// `OiHelpCenter`, via typed field bindings.
///
/// Chosen over reusing [BeakAccordionBlock] because `OiHelpCenter` adds
/// materially more — built-in search and category grouping over the same
/// question/answer pairs. [questionField] and [answerField] fill each entry;
/// [categoryField] (when bound) groups them.
///
/// ```dart
/// BeakFaqBlock(
///   model: const FaqModel(),
///   questionField: FaqModel.question.column,
///   answerField: FaqModel.answer.column,
///   categoryField: FaqModel.category.column,
/// );
/// ```
final class BeakFaqBlock extends BeakBlock {
  /// Creates an FAQ block over [model].
  const BeakFaqBlock({
    required this.model,
    required this.questionField,
    required this.answerField,
    this.categoryField,
    this.sortField,
    this.label = 'Help',
    this.filter,
    super.span,
  });

  /// The model whose records become FAQ entries.
  final BeakModel model;

  /// Column supplying each entry's question.
  final BeakColumn questionField;

  /// Column supplying each entry's answer (Markdown supported).
  final BeakColumn answerField;

  /// Column grouping entries into categories, when bound.
  final BeakColumn? categoryField;

  /// Column ordering the entries, when bound.
  final BeakColumn? sortField;

  /// Accessibility label for the help center.
  final String label;

  /// Narrows the rows the block lists. A block reads one page of at most
  /// [BeakPagination.maxPerPage] rows, and says so beneath itself when the
  /// query matches more.
  final BeakFilter? filter;
}
