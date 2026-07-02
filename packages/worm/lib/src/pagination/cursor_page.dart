/// A single cursor-paginated page of results.
library;

import 'cursor.dart';

/// Immutable result of a `cursorPaginate` call.
///
/// `nextCursor` is `null` when this is the last page.
/// All fields are final — pages are value types.
final class CursorPage<T> {
  /// Creates a [CursorPage].
  const CursorPage({
    required this.data,
    required this.perPage,
    this.nextCursor,
  });

  /// Hydrated rows on this page.
  final List<T> data;

  /// Items per page used to compute the slice.
  final int perPage;

  /// Cursor to the next page, or `null` at the end.
  final Cursor? nextCursor;

  /// Whether more pages follow this one.
  bool get hasMorePages => nextCursor != null;

  /// Encoded next-cursor token, or `null` at the end.
  String? get nextToken => nextCursor?.encode();
}
