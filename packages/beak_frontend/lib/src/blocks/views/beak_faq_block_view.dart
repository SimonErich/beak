part of '../beak_block_host.dart';

/// Fetches a [BeakFaqBlock]'s records, maps each to an [OiFaqItem], and
/// renders them on `OiHelpCenter` (FAQ tab only) — search and categories
/// come for free.
class _BeakFaqBlockView extends HookWidget {
  const _BeakFaqBlockView({required this.block});

  final BeakFaqBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakLocator<BeakDataSource>();
    final records = useState(const <BeakRecord>[]);

    useEffect(() {
      var cancelled = false;
      Future<void> load() async {
        final result = await BeakResourceRepository(
          dataSource,
        ).query(BeakQuerySpec(table: block.model.table));
        if (cancelled) {
          return;
        }
        if (result case BeakOk(:final value)) {
          records.value = value.items;
        }
      }

      load();
      return () => cancelled = true;
    }, [dataSource, block]);

    return OiHelpCenter(
      label: block.label,
      showContact: false,
      showKnowledgeBase: false,
      showFeedback: false,
      faq: [
        for (final record in records.value)
          OiFaqItem(
            question: _readString(record, block.questionField) ?? '',
            answer: _readString(record, block.answerField) ?? '',
            category: _readString(record, block.categoryField),
          ),
      ],
    );
  }
}
