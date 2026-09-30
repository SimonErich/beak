import 'package:meta/meta.dart';

import '../common/beak_exception.dart';
import '../common/json_support.dart';

/// The paging window of a query spec: a 1-based [page] of [perPage] records.
@immutable
final class BeakPagination {
  /// Creates a paging window on 1-based [page] with [perPage] records.
  const BeakPagination({this.page = 1, this.perPage = 25})
    : assert(page >= 1, 'page is 1-based and must be >= 1'),
      assert(perPage >= 1, 'perPage must be >= 1');

  /// Decodes [json] (produced by [toJson]).
  ///
  /// Both keys are optional: an absent or `null` `page` is 1 and an absent or
  /// `null` `perPage` is 25, the constructor defaults, so a hand-written
  /// request sends only the half it means. [toJson] still writes both.
  ///
  /// Throws a [BeakConfigurationException] on malformed input, including
  /// non-positive pages or page sizes.
  static BeakPagination fromJson(Map<String, Object?> json) {
    const BeakPagination defaults = BeakPagination();
    final int page = optionalJsonInt(
      json,
      'page',
      'BeakPagination',
      orElse: defaults.page,
    );
    final int perPage = optionalJsonInt(
      json,
      'perPage',
      'BeakPagination',
      orElse: defaults.perPage,
    );
    if (page < 1 || perPage < 1) {
      throw BeakConfigurationException(
        'BeakPagination requires page >= 1 and perPage >= 1, '
        'got page $page, perPage $perPage.',
      );
    }
    return BeakPagination(page: page, perPage: perPage);
  }

  /// The largest page size a server serves by default; a request for more is
  /// answered with this many records per page, and the page envelope reports
  /// the size actually used.
  ///
  /// A caller that needs more rows pages through them, or asks a summary or
  /// aggregate for the totals it wants instead of fetching every row.
  static const int maxPerPage = 200;

  /// The 1-based page number to fetch.
  final int page;

  /// The number of records per page.
  final int perPage;

  /// This paging window as a plain JSON-encodable object.
  Map<String, Object?> toJson() => {'page': page, 'perPage': perPage};

  @override
  bool operator ==(Object other) =>
      other is BeakPagination && other.page == page && other.perPage == perPage;

  @override
  int get hashCode => Object.hash(page, perPage);

  @override
  String toString() => 'BeakPagination(page $page, perPage $perPage)';
}
