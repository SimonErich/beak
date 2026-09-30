part of '../beak_block_host.dart';

/// Typed field readers shared by the data-bound module views: each resolves
/// a bound [BeakColumn] against a [BeakRecord] by the column's key, so a view
/// never touches a raw field string.

/// The page module views fetch: the most rows a server answers with
/// ([BeakPagination.maxPerPage]). A board, transcript, inbox or plan grid that
/// matches more rows shows a note saying so (see [_withTruncationNote]) and
/// takes a `filter` to narrow what it lists.
const BeakPagination _modulePage = BeakPagination(
  perPage: BeakPagination.maxPerPage,
);

/// The rows a module view drew and how many its query matched in all.
final class _ModuleRows {
  /// The rows of one fetched page and the size of the whole result.
  ///
  /// [failure] and [retry] describe a read that failed: the rows are then the
  /// last ones that were read, and [retry] reads again.
  const _ModuleRows(this.records, this.total, {this.failure, this.retry});

  /// Nothing fetched yet.
  const _ModuleRows.empty()
    : records = const [],
      total = 0,
      failure = null,
      retry = null;

  /// The fetched rows, in query order.
  final List<BeakRecord> records;

  /// How many rows the query matched across all pages.
  final int total;

  /// Why the last read failed, or null when it did not.
  final BeakException? failure;

  /// Reads again after a failure.
  final VoidCallback? retry;

  /// Whether the query matched more rows than were fetched.
  bool get truncated => total > records.length;
}

/// Runs [spec] against [dataSource], and again whenever a write to its table
/// is confirmed or [_ModuleRows.retry] is called.
///
/// The notifier is writable so a view can mirror a confirmed write into what it
/// draws before the refetch lands.
ValueNotifier<_ModuleRows> _useModuleRows(
  BeakDataSource dataSource,
  BeakQuerySpec spec,
) {
  final rows = useState(const _ModuleRows.empty());
  final attempt = useState(0);
  final revision = useBeakDataRevision(dataSource, table: spec.table);
  useEffect(() {
    var cancelled = false;
    Future<void> load() async {
      final result = await BeakResourceRepository(dataSource).query(spec);
      if (cancelled) {
        return;
      }
      rows.value = switch (result) {
        BeakOk(:final value) => _ModuleRows(value.items, value.total),
        // What was read before stays: an empty board would say "nothing is
        // here" about a read that never happened.
        BeakErr(:final error) => _ModuleRows(
          rows.value.records,
          rows.value.total,
          failure: error,
          retry: () => attempt.value++,
        ),
      };
    }

    load();
    return () => cancelled = true;
  }, [dataSource, jsonEncode(spec.toJson()), revision, attempt.value]);
  return rows;
}

/// What a block that reads for itself has: its mapped [data], the [failure] of
/// the last read (the previous [data] stays while it is shown), and a [retry].
final class _BlockRead<T> {
  /// Captures one moment of a block's read.
  const _BlockRead(this.data, this.failure, this.retry);

  /// What the block draws from the last successful read.
  final T data;

  /// Why the last read failed, or null when it did not.
  final BeakException? failure;

  /// Reads again.
  final VoidCallback retry;
}

/// Runs [spec] through [dataSource] and maps each answer with [map], again
/// whenever a write to its table is confirmed, the [spec] changes by value or
/// [_BlockRead.retry] is called.
///
/// A screen that builds its block tree inside `build` hands the view a new
/// block object on every rebuild; only a different query reads again.
///
/// [initial] is what the block draws until the first answer arrives. A failed
/// read keeps the previous data and reports itself through
/// [_BlockRead.failure], which [_withReadFailure] draws.
_BlockRead<T> _useBlockRead<T>(
  BeakDataSource dataSource,
  BeakQuerySpec spec, {
  required T initial,
  required T Function(BeakPage<BeakRecord> page) map,
}) {
  final data = useState(initial);
  final failure = useState<BeakException?>(null);
  final attempt = useState(0);
  final revision = useBeakDataRevision(dataSource, table: spec.table);
  useEffect(() {
    var cancelled = false;
    Future<void> load() async {
      final result = await BeakResourceRepository(dataSource).query(spec);
      if (cancelled) {
        return;
      }
      switch (result) {
        case BeakOk(:final value):
          data.value = map(value);
          failure.value = null;
        case BeakErr(:final error):
          failure.value = error;
      }
    }

    load();
    return () => cancelled = true;
  }, [dataSource, jsonEncode(spec.toJson()), revision, attempt.value]);
  return _BlockRead(data.value, failure.value, () => attempt.value++);
}

/// [view] with the failure of [read] above it and a Retry, or [view] alone.
Widget _withReadFailure(
  BuildContext context,
  _BlockRead<Object?> read,
  Widget view,
) => _withFailure(context, read.failure, read.retry, view);

/// [view] with [failure] and a [retry] above it, or [view] alone when nothing
/// failed. The message is the panel's own, so an infrastructure detail never
/// reaches the screen.
Widget _withFailure(
  BuildContext context,
  BeakException? failure,
  VoidCallback? retry,
  Widget view,
) {
  if (failure == null) {
    return view;
  }
  final strings = BeakLocalizations.of(context);
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: OiLabel.caption(strings.errorMessage(failure))),
          if (retry != null)
            OiButton.ghost(
              size: OiButtonSize.small,
              label: strings.retry,
              onTap: retry,
            ),
        ],
      ),
      const SizedBox(height: 8),
      Flexible(child: view),
    ],
  );
}

/// [view] with a note beneath it when [rows] holds only part of the result, and
/// the failure of the last read above it.
Widget _withTruncationNote(
  BuildContext context,
  _ModuleRows rows,
  Widget view,
) {
  final Widget noted = !rows.truncated
      ? view
      : Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(child: view),
            const SizedBox(height: 8),
            OiLabel.caption(
              BeakLocalizations.of(
                context,
              ).showingFirst(rows.records.length, rows.total),
            ),
          ],
        );
  return _withFailure(context, rows.failure, rows.retry, noted);
}

/// Tells the user a write from a module view was refused, in the words the
/// rest of the panel uses for a failure.
void _reportWriteFailure(BuildContext context, BeakException error) {
  BeakOverlays(context).toast(
    BeakLocalizations.of(context).errorMessage(error),
    level: OiToastLevel.error,
  );
}

/// The string value of [column] in [record], or `null` when unbound or empty.
String? _readString(BeakRecord record, BeakColumn? column) {
  if (column == null) {
    return null;
  }
  return record[column.key]?.raw?.toString();
}

/// Whether [column]'s value in [record] is boolean `true`; `false` when
/// unbound.
bool _readBool(BeakRecord record, BeakColumn? column) =>
    column != null && record[column.key]?.raw == true;

/// The [DateTime] value of [column] in [record], parsing ISO strings, or
/// `null` when unbound or unparseable.
DateTime? _readDateTime(BeakRecord record, BeakColumn? column) {
  if (column == null) {
    return null;
  }
  return switch (record[column.key]?.raw) {
    final DateTime value => value,
    final String value => DateTime.tryParse(value),
    _ => null,
  };
}

/// The integer value of [column] in [record], or `null` when unbound.
int? _readInt(BeakRecord record, BeakColumn? column) {
  if (column == null) {
    return null;
  }
  return switch (record[column.key]?.raw) {
    final int value => value,
    final num value => value.toInt(),
    final String value => int.tryParse(value),
    _ => null,
  };
}

/// The double value of [column] in [record], or `null` when unbound.
double? _readDouble(BeakRecord record, BeakColumn? column) {
  if (column == null) {
    return null;
  }
  return switch (record[column.key]?.raw) {
    final num value => value.toDouble(),
    final String value => double.tryParse(value),
    _ => null,
  };
}

/// Resolves a semantic [BeakColor] to a concrete theme color, or `null` when
/// [color] is unset.
// --8<-- [start:resolveBeakColor]
Color? _resolveBeakColor(BuildContext context, BeakColor? color) {
  final colors = context.colors;
  return switch (color) {
    null => null,
    BeakColor.primary => colors.primary.base,
    BeakColor.secondary => colors.accent.base,
    BeakColor.success => colors.success.base,
    BeakColor.warning => colors.warning.base,
    BeakColor.error => colors.error.base,
    BeakColor.info => colors.info.base,
    BeakColor.muted => colors.textMuted,
  };
}
// --8<-- [end:resolveBeakColor]
