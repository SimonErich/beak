import 'package:bookshop_server/src/generated/protocol.dart' as sp;
import 'package:serverpod/serverpod.dart' show Session;

/// The `scope=serverOnly` value every fixture book carries.
const int leakSupplierCostInCents = 7777777;

/// Everything that must never appear in anything Beak returns or stores.
const List<String> leakMarkers = ['supplierCostInCents', '7777777'];

/// The markers found in [text] (empty when it is clean).
List<String> leaksIn(String text) => [
  for (final marker in leakMarkers)
    if (text.contains(marker)) marker,
];

/// Two authors and three books, inserted through Serverpod's typed ORM.
///
/// Every book carries [leakSupplierCostInCents] in its server-only column.
final class Catalog {
  Catalog._(this.tove, this.ursula, this.books);

  /// Wrote the first two books.
  final sp.Author tove;

  /// Wrote the third book.
  final sp.Author ursula;

  /// The books, in insertion order.
  final List<sp.Book> books;

  /// Seeds on [session].
  static Future<Catalog> seed(Session session) async {
    final tove = await sp.Author.db.insertRow(
      session,
      sp.Author(name: 'Tove Jansson'),
    );
    final ursula = await sp.Author.db.insertRow(
      session,
      sp.Author(name: 'Ursula K. Le Guin'),
    );
    final books = await sp.Book.db.insert(session, [
      for (final (index, title, author) in [
        (0, 'Comet in Moominland', tove),
        (1, 'Finn Family Moomintroll', tove),
        (2, 'A Wizard of Earthsea', ursula),
      ])
        sp.Book(
          title: title,
          isbn: '978-9-99-00000$index',
          format: sp.BookFormat.paperback,
          priceInCents: 1200 + index,
          stock: 5,
          supplierCostInCents: leakSupplierCostInCents,
          authorId: author.id!,
        ),
    ]);
    return Catalog._(tove, ursula, books);
  }
}
