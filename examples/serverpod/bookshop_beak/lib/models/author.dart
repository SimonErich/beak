import 'package:beak_core/beak_core.dart';
import 'package:beak_core/schema.dart';

import 'book.dart';

part 'author.beak.dart';

/// Someone whose books the shop sells.
///
/// Describes the Serverpod table `author`. Serverpod owns that table
/// (`managesSchema: false`), so its physical column names, which are
/// camelCase, are spelled out where they differ from Beak's snake_case
/// default.
@Resource(table: 'author', managesSchema: false)
final class Author extends BeakSchema {
  /// Serverpod's serial id, assigned by the database.
  @Column(visibleOn: {BeakContext.detail})
  late final int? id;

  /// The name printed on the cover.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(120)])
  late final String name;

  /// A short biography for the author page.
  late final BeakText? bio;

  /// The author's own website.
  @Column(semantic: BeakSemantic.url())
  late final String? website;

  /// Every book this author wrote.
  @HasMany(foreignKey: 'authorId', onDelete: BeakOnDelete.cascade)
  late final List<Book>? books;
}
