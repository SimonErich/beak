part of '../beak_block_host.dart';

/// The synthetic sender id marking a [BeakChatBlock]'s own (outgoing)
/// messages, so `OiChat` right-aligns their bubbles.
const String _kBeakChatCurrentUser = '__beak_chat_me__';

/// Fetches a [BeakChatBlock]'s records, orders them by time, and renders them
/// as bubbles on `OiChat` — own messages on the outgoing side.
class _BeakChatBlockView extends HookWidget {
  const _BeakChatBlockView({required this.block});

  final BeakChatBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakDependencies(context)<BeakDataSource>();
    final records = useState(const <BeakRecord>[]);

    useEffect(() {
      var cancelled = false;
      Future<void> load() async {
        // Fetch newest-first so that if the transcript ever exceeds the page,
        // it is the oldest messages that fall off — never the latest.
        final result = await BeakResourceRepository(dataSource).query(
          BeakQuerySpec(
            table: block.model.table,
            sorts: [BeakSort(block.timeField.key, descending: true)],
            pagination: _modulePage,
          ),
        );
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

    final ordered = [...records.value]
      ..sort((a, b) {
        final DateTime? left = _readDateTime(a, block.timeField);
        final DateTime? right = _readDateTime(b, block.timeField);
        if (left == null || right == null) {
          return 0;
        }
        return left.compareTo(right);
      });

    return OiChat(
      label: block.label,
      currentUserId: _kBeakChatCurrentUser,
      messages: [
        for (final (index, record) in ordered.indexed)
          _messageOf(index, record),
      ],
      onSend: block.composeRecord == null
          ? null
          : (text) async {
              final body = text.trim();
              if (body.isEmpty) {
                return;
              }
              final result = await BeakResourceRepository(
                dataSource,
              ).create(block.model.table, block.composeRecord!(body));
              if (result case BeakOk(:final value)) {
                records.value = [...records.value, value];
              }
            },
    );
  }

  OiChatMessage _messageOf(int index, BeakRecord record) {
    final bool mine = _readBool(record, block.isMineField);
    final String author = _readString(record, block.authorField) ?? '';
    return OiChatMessage(
      key: block.model.primaryKeyOf(record) ?? index,
      senderId: mine ? _kBeakChatCurrentUser : author,
      senderName: author,
      content: _readString(record, block.bodyField) ?? '',
      timestamp: _readDateTime(record, block.timeField) ?? DateTime.now(),
    );
  }
}
