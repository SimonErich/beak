part of '../beak_block_host.dart';

/// Fetches a [BeakFaqBlock]'s records, maps each to an [OiFaqItem], and
/// renders them on `OiHelpCenter` (FAQ tab only) — search and categories
/// come for free.
class _BeakFaqBlockView extends HookWidget {
  const _BeakFaqBlockView({required this.block});

  final BeakFaqBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakDependencies(context)<BeakDataSource>();
    final rows = _useModuleRows(
      dataSource,
      BeakQuerySpec(
        table: block.model.table,
        filter: block.filter,
        sorts: [
          if (block.sortField case final BeakColumn column)
            BeakSort(column.key),
        ],
        pagination: _modulePage,
      ),
    );

    return _withTruncationNote(
      context,
      rows.value,
      OiHelpCenter(
        label: block.label,
        showContact: false,
        showKnowledgeBase: false,
        showFeedback: false,
        faq: [
          for (final record in rows.value.records)
            OiFaqItem(
              question: _readString(record, block.questionField) ?? '',
              answer: _readString(record, block.answerField) ?? '',
              category: _readString(record, block.categoryField),
            ),
        ],
      ),
    );
  }
}
