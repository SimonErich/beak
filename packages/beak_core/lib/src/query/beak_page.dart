import 'package:meta/meta.dart';

import '../common/beak_exception.dart';
import '../common/list_equality.dart';
import '../common/json_support.dart';

/// One page of query results plus its paging envelope — what the backend
/// returns for a query spec.
///
/// The envelope is generic over the item type and serializes through caller
/// supplied item (de)serializers, so it never exposes `dynamic`.
///
/// ```dart
/// // Decode a page of records the backend returned for a query spec.
/// final BeakPage<BeakRecord> page = BeakPage.fromJson(
///   json,
///   (itemJson) => switch (itemJson) {
///     final Map<String, Object?> map => BeakRecord.fromJson(map),
///     _ => throw const BeakConfigurationException('expected a record'),
///   },
/// );
///
/// final bool hasMore = page.page * page.perPage < page.total;
/// ```
@immutable
final class BeakPage<T> {
  /// Creates a page of [items] out of [total] matching records, at 1-based
  /// [page] with [perPage] records per page.
  const BeakPage({
    required this.items,
    required this.total,
    required this.page,
    required this.perPage,
  });

  /// Decodes [json] (produced by [toJson]), decoding each element of
  /// `items` with [decodeItem].
  ///
  /// Throws a [BeakConfigurationException] on a malformed envelope; item
  /// deserialization failures propagate from [decodeItem].
  static BeakPage<T> fromJson<T>(
    Map<String, Object?> json,
    T Function(Object? itemJson) decodeItem,
  ) {
    final items = switch (requireJsonKey(json, 'items', 'BeakPage')) {
      final List<Object?> values => [
        for (final value in values) decodeItem(value),
      ],
      final Object? other => throw BeakConfigurationException(
        'BeakPage JSON key "items" must be a list, got $other.',
      ),
    };
    return BeakPage(
      items: items,
      total: requireJsonInt(json, 'total', 'BeakPage'),
      page: requireJsonInt(json, 'page', 'BeakPage'),
      perPage: requireJsonInt(json, 'perPage', 'BeakPage'),
    );
  }

  /// The records of this page, in result order.
  final List<T> items;

  /// Total number of records matching the query across all pages.
  final int total;

  /// The 1-based page number this page represents.
  final int page;

  /// The page size the query used.
  final int perPage;

  /// This page as a plain JSON-encodable object, encoding each item with
  /// [encodeItem].
  // --8<-- [start:toJson]
  Map<String, Object?> toJson(Object? Function(T item) encodeItem) => {
    'items': [for (final item in items) encodeItem(item)],
    'total': total,
    'page': page,
    'perPage': perPage,
  };
  // --8<-- [end:toJson]

  @override
  bool operator ==(Object other) =>
      other is BeakPage<T> &&
      other.total == total &&
      other.page == page &&
      other.perPage == perPage &&
      listEquals(other.items, items);

  @override
  int get hashCode => Object.hash(Object.hashAll(items), total, page, perPage);

  @override
  String toString() =>
      'BeakPage(${items.length} of $total items, page $page, '
      'perPage $perPage)';
}
