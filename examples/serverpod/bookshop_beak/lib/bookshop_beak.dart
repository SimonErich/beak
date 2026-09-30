/// Beak models of the bookshop (pure Dart, web-safe).
///
/// The schema classes `Author` and `Book` are hidden: their names are the
/// Serverpod protocol classes' names, and code that needs both imports the
/// protocol with a prefix. Use the generated `AuthorModel` and `BookModel`
/// (typed field references), and `buildBeakRegistry()` for the server.
library;

export 'beak/registry.g.dart';
export 'models/author.dart' hide Author;
export 'models/book.dart' hide Book;
export 'models/book_format.dart';
