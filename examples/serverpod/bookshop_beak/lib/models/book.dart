import 'package:beak_core/beak_core.dart';
import 'package:beak_core/schema.dart';

import 'author.dart';
import 'book_format.dart';

part 'book.beak.dart';

// --8<-- [start:Book]
/// A title the shop stocks.
///
/// Describes the Serverpod table `book`. The server-only supplier cost column
/// is deliberately not declared here: what Beak does not model never leaves
/// the server through Beak.
@Resource(table: 'book', managesSchema: false)
final class Book extends BeakSchema {
  /// Serverpod's serial id, assigned by the database.
  @Column(visibleOn: {BeakContext.detail})
  late final int? id;

  /// The title printed on the cover.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(200)])
  late final String title;

  /// The ISBN, unique per edition.
  @Column(label: 'ISBN', searchable: true, unique: true)
  late final String isbn;

  /// How the book is bound.
  @Column(filterable: true)
  late final BookFormat format;

  /// Shelf price in cents.
  @Column(
    columnName: 'priceInCents',
    label: 'Price in cents',
    sortable: true,
    rules: [BeakMin(0)],
  )
  late final int priceInCents;

  /// Copies on the shelf.
  @Column(sortable: true, defaultValue: 0, rules: [BeakMin(0)])
  late final int stock;

  /// First publication date.
  @Column(
    columnName: 'publishedOn',
    label: 'Published',
    format: BeakDateFormat.dateOnly,
    sortable: true,
  )
  late final DateTime? publishedOn;

  /// Who wrote it.
  @BelongsTo(
    foreignKey: 'authorId',
    onDelete: BeakOnDelete.cascade,
    inverse: false,
  )
  late final Author author;
}
// --8<-- [end:Book]
