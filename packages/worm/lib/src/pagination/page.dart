/// Immutable result of an offset-based `paginate` call.
library;

/// A page of hydrated rows with offset metadata.
///
/// Carries the row range plus enough metadata to render
/// "showing X – Y of Z" UIs without inspecting the
/// underlying query. All fields are final — pages are
/// value types, never mutated.
final class Page<T> {
  /// Creates a [Page].
  const Page({
    required this.data,
    required this.currentPage,
    required this.perPage,
    required this.total,
  });

  /// Hydrated rows on this page.
  final List<T> data;

  /// 1-based current page index.
  final int currentPage;

  /// Items per page used to compute the slice.
  final int perPage;

  /// Total rows matching the underlying query.
  final int total;

  /// Total number of pages (always >= 1, even when
  /// empty).
  int get lastPage => total == 0 ? 1 : ((total - 1) ~/ perPage) + 1;

  /// Whether more pages follow this one.
  bool get hasMorePages => currentPage < lastPage;

  /// 1-based index of the first row on this page.
  ///
  /// Returns `0` for empty pages (no rows present).
  int get from {
    if (data.isEmpty) return 0;
    return (currentPage - 1) * perPage + 1;
  }

  /// 1-based index of the last row on this page.
  ///
  /// Returns `0` for empty pages.
  int get to {
    if (data.isEmpty) return 0;
    return (currentPage - 1) * perPage + data.length;
  }
}
