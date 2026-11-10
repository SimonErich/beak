import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod/schema.dart';

import '../generated/enums.dart';
import '../generated/writes.dart';
import 'author.dart';

part 'book.beak.dart';

/// A title the shop stocks. Staff create and edit books; nobody deletes
/// one, so removing a book is a deliberate server change.
@Resource()
@ServerpodModel(
  area: 'catalog',
  create: BeakHandling.stock,
  update: BeakHandling.stock,
)
final class Book extends BeakSchema {
  /// The title printed on the cover.
  @Display()
  late final String title;

  /// The ISBN, unique per edition.
  late final String isbn;

  /// How the book is bound.
  late final BookFormat format;

  /// Shelf price in cents.
  late final int priceInCents;

  /// Copies on the shelf.
  late final int stock;

  /// First publication date.
  late final DateTime? publishedOn;

  /// Who wrote it.
  @BelongsTo()
  late final Author? author;

  // supplierCostInCents is server only in Serverpod and not declared here,
  // so the admin never reads or writes it.
}
