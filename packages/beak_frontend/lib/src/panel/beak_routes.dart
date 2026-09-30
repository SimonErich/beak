/// The canonical route paths of a Beak panel — every navigation and route
/// registration derives from these builders, so the path shapes live in
/// exactly one place.
abstract final class BeakRoutes {
  /// The list page of [table].
  static String list(String table) => '/$table';

  /// The create page of [table].
  static String create(String table) => '/$table/create';

  /// The show page of record [id] of [table].
  ///
  /// The id is one path segment: a `/`, `?` or `#` in it is escaped, so a
  /// record keyed by a slug or a code opens the page it names and no other.
  static String show(String table, Object id) =>
      '/$table/${Uri.encodeComponent(id.toString())}';

  /// The edit page of record [id] of [table].
  static String edit(String table, Object id) => '${show(table, id)}/edit';
}
