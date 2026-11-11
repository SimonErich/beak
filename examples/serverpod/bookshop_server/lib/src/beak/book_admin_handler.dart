import 'package:beak_core/beak_core.dart';
import 'package:bookshop_server/src/beak/generated/book_handler.dart';
import 'package:bookshop_server/src/generated/protocol.dart' as sp;

/// Runs the bookshop's book commands against Serverpod's typed ORM.
final class BookAdminHandler extends BookHandler {
  /// Creates the handler.
  const BookAdminHandler();

  static const _restockBy = 5;

  @override
  Future<Object?> restock(BookWrite write) async {
    final id = write.record.id;
    if (id == null) {
      throw const BeakNotFoundException('The book no longer exists.');
    }
    final book = await sp.Book.db.findById(
      write.session,
      id,
      transaction: write.transaction,
    );
    if (book == null) {
      throw const BeakNotFoundException('The book no longer exists.');
    }
    await sp.Book.db.updateRow(
      write.session,
      book.copyWith(stock: book.stock + _restockBy),
      transaction: write.transaction,
    );
    return id;
  }
}
