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
    // Fetch newest-first so that if the transcript ever exceeds the page, it
    // is the oldest messages that fall off — never the latest.
    final rows = _useModuleRows(
      dataSource,
      BeakQuerySpec(
        table: block.model.table,
        filter: block.filter,
        sorts: [BeakSort(block.timeField.key, descending: true)],
        pagination: _modulePage,
      ),
    );

    final ordered = [...rows.value.records]
      ..sort((a, b) {
        final DateTime? left = _readDateTime(a, block.timeField);
        final DateTime? right = _readDateTime(b, block.timeField);
        if (left == null || right == null) {
          return 0;
        }
        return left.compareTo(right);
      });

    final formatting = BeakFormatting.of(context);
    return _withTruncationNote(
      context,
      rows.value,
      OiChat(
        label: block.label,
        currentUserId: _kBeakChatCurrentUser,
        messages: [
          for (final (index, record) in ordered.indexed)
            _messageOf(formatting, index, record),
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
                switch (result) {
                  case BeakOk(:final value):
                    rows.value = _ModuleRows([
                      ...rows.value.records,
                      value,
                    ], rows.value.total + 1);
                  case BeakErr(:final error):
                    if (context.mounted) _reportWriteFailure(context, error);
                }
              },
      ),
    );
  }

  OiChatMessage _messageOf(
    BeakFormatting formatting,
    int index,
    BeakRecord record,
  ) {
    final bool mine = _readBool(record, block.isMineField);
    final String author = _readString(record, block.authorField) ?? '';
    return OiChatMessage(
      key: block.model.primaryKeyOf(record) ?? index,
      senderId: mine ? _kBeakChatCurrentUser : author,
      senderName: author,
      content: _readString(record, block.bodyField) ?? '',
      timestamp: formatting.toEditorDateTime(
        _readDateTime(record, block.timeField) ?? DateTime.now(),
      ),
    );
  }
}
