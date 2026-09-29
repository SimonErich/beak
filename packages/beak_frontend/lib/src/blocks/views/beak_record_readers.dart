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
  const _ModuleRows(this.records, this.total);

  /// Nothing fetched yet.
  const _ModuleRows.empty() : records = const [], total = 0;

  /// The fetched rows, in query order.
  final List<BeakRecord> records;

  /// How many rows the query matched across all pages.
  final int total;

  /// Whether the query matched more rows than were fetched.
  bool get truncated => total > records.length;
}

/// Runs [spec] against [dataSource], and again whenever a write to its table
/// is confirmed.
///
/// The notifier is writable so a view can mirror a confirmed write into what it
/// draws before the refetch lands.
ValueNotifier<_ModuleRows> _useModuleRows(
  BeakDataSource dataSource,
  BeakQuerySpec spec,
) {
  final rows = useState(const _ModuleRows.empty());
  final revision = useBeakDataRevision(dataSource, table: spec.table);
  useEffect(() {
    var cancelled = false;
    Future<void> load() async {
      final result = await BeakResourceRepository(dataSource).query(spec);
      if (cancelled) {
        return;
      }
      if (result case BeakOk(:final value)) {
        rows.value = _ModuleRows(value.items, value.total);
      }
    }

    load();
    return () => cancelled = true;
  }, [dataSource, jsonEncode(spec.toJson()), revision]);
  return rows;
}

/// [view] with a note beneath it when [rows] holds only part of the result.
Widget _withTruncationNote(
  BuildContext context,
  _ModuleRows rows,
  Widget view,
) => !rows.truncated
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
