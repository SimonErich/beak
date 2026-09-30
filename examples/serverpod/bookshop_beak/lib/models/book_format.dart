/// How a book is bound (or not bound at all).
///
/// Mirrors the Serverpod enum `BookFormat` (`book_format.spy.yaml`, stored by
/// name). Keep the two lists identical: the value names are what the database
/// holds.
enum BookFormat {
  /// A paperback edition.
  paperback,

  /// A hardcover edition.
  hardcover,

  /// A digital edition.
  ebook,
}
