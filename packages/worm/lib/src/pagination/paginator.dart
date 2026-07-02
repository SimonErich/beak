/// Top-level pagination primitives.
///
/// These functions are the canonical API for offset
/// and cursor pagination — `QueryBuilder` exposes thin
/// wrappers that delegate here. Pagination lives as
/// top-level functions rather than QueryBuilder methods
/// so callers without a builder context can still
/// paginate raw descriptors.
library;

import '../model/model.dart';
import '../query/aggregate_descriptor.dart';
import '../query/eager_load.dart';
import '../query/field.dart';
import '../query/field_operators.dart';
import '../query/query_context.dart';
import '../query/query_descriptor.dart';
import '../query/sort_clause.dart';
import '../relation/eager_loader.dart';
import 'cursor.dart';
import 'cursor_page.dart';
import 'page.dart';

/// Offset-based paginate.
///
/// Executes one SELECT for the page slice (using LIMIT
/// + OFFSET) and one COUNT for [Page.total]. Hydrates
/// rows into [T] via `context.hydrate` and resolves any
/// requested [loads] / [aggregates] on the resulting
/// page.
///
/// Returns a [Page] with `data` capped to [perPage] and
/// `currentPage` equal to [page]. When [page] runs past
/// the last available page, `data` is empty and
/// `from`/`to` are `0`.
Future<Page<T>> paginate<T extends Model>({
  required QueryContext<T> context,
  required QueryDescriptor descriptor,
  int page = 1,
  int perPage = 15,
  List<EagerLoad> loads = const <EagerLoad>[],
  List<AggregateInjection> aggregates = const <AggregateInjection>[],
}) async {
  final pageDesc = descriptor.copyWith(
    limit: perPage,
    offset: (page - 1) * perPage,
  );
  final rows = await context.adapter.select(pageDesc);
  final data = <T>[for (final row in rows) context.hydrate(row)];
  final total = await context.adapter.count(
    AggregateDescriptor.count(table: pageDesc.table, where: pageDesc.where),
  );
  await EagerLoader.run(
    context: context,
    parents: data,
    loads: loads,
    aggregates: aggregates,
  );
  return Page<T>(data: data, currentPage: page, perPage: perPage, total: total);
}

/// Cursor-based paginate ordered by primary key
/// ascending.
///
/// The implementation issues a single SELECT requesting
/// `perPage + 1` rows; the extra row signals "more
/// pages follow". When a [cursor] is supplied, an
/// additional `WHERE <field> > <value>` clause is
/// appended — the column is the cursor's [Cursor.field]
/// when present, otherwise the context's primary key.
///
/// Callers may either pass a decoded [cursor] directly
/// or the encoded token string via [after]; both are
/// equivalent. Supplying both throws
/// [ArgumentError] — pick exactly one.
///
/// Returns a [CursorPage] with `nextCursor` set when
/// more rows exist, or `null` on the final page.
Future<CursorPage<T>> cursorPaginate<T extends Model>({
  required QueryContext<T> context,
  required QueryDescriptor descriptor,
  int perPage = 15,
  Cursor? cursor,
  String? after,
  List<EagerLoad> loads = const <EagerLoad>[],
  List<AggregateInjection> aggregates = const <AggregateInjection>[],
}) async {
  if (cursor != null && after != null) {
    throw ArgumentError(
      'cursorPaginate accepts either cursor or after, not both',
    );
  }
  cursor ??= Cursor.decode(after);
  final cursorField = cursor?.field ?? context.primaryKey;
  final keyField = ComparableField<Object>(cursorField);
  final baseWhere = descriptor.where;
  final cursorValue = cursor?.value;
  final advanced = cursorValue == null
      ? baseWhere
      : (baseWhere == null
            ? keyField.gt(cursorValue)
            : baseWhere.and(keyField.gt(cursorValue)));
  final orderBy = descriptor.orderBy.isEmpty
      ? <SortClause>[SortClause(cursorField)]
      : descriptor.orderBy;
  final pageDesc = descriptor.copyWith(
    where: advanced,
    clearWhere: advanced == null,
    orderBy: orderBy,
    limit: perPage + 1,
  );
  final rows = await context.adapter.select(pageDesc);
  final hasMore = rows.length > perPage;
  final visible = hasMore ? rows.sublist(0, perPage) : rows;
  final data = <T>[for (final row in visible) context.hydrate(row)];
  Cursor? next;
  if (hasMore && data.isNotEmpty) {
    final lastRow = visible.last;
    final fieldValue = lastRow[cursorField];
    final lastId = data.last.id;
    if (fieldValue != null) {
      next = Cursor(field: cursorField, value: fieldValue, id: lastId);
    }
  }
  await EagerLoader.run(
    context: context,
    parents: data,
    loads: loads,
    aggregates: aggregates,
  );
  return CursorPage<T>(data: data, perPage: perPage, nextCursor: next);
}
