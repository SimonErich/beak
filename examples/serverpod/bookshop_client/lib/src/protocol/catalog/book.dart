/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:bookshop_client/src/protocol/protocol.dart' as _i77qvqjx;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import '../catalog/author.dart' as _ikaricya;
import '../catalog/book_format.dart' as _ie1s4qve;

/// A title the shop stocks.
abstract class Book
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  Book._({
    this.id,
    required this.title,
    required this.isbn,
    required this.format,
    required this.priceInCents,
    int? stock,
    this.publishedOn,
    required this.authorId,
    this.author,
  }) : stock = stock ?? 0;

  factory Book({
    int? id,
    required String title,
    required String isbn,
    required _ie1s4qve.BookFormat format,
    required int priceInCents,
    int? stock,
    DateTime? publishedOn,
    required int authorId,
    _ikaricya.Author? author,
  }) = _BookImpl;

  factory Book.fromJson(Map<String, dynamic> jsonSerialization) {
    return Book(
      id: jsonSerialization['id'] as int?,
      title: jsonSerialization['title'] as String,
      isbn: jsonSerialization['isbn'] as String,
      format: _ie1s4qve.BookFormat.fromJson(
        (jsonSerialization['format'] as String),
      ),
      priceInCents: jsonSerialization['priceInCents'] as int,
      stock: jsonSerialization['stock'] as int?,
      publishedOn: jsonSerialization['publishedOn'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['publishedOn'],
            ),
      authorId: jsonSerialization['authorId'] as int,
      author: jsonSerialization['author'] == null
          ? null
          : _i77qvqjx.Protocol().deserialize<_ikaricya.Author>(
              jsonSerialization['author'],
            ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  /// The title printed on the cover.
  String title;

  /// The ISBN, unique per edition.
  String isbn;

  /// How the book is bound.
  _ie1s4qve.BookFormat format;

  /// Shelf price in cents.
  int priceInCents;

  /// Copies on the shelf.
  int stock;

  /// First publication date.
  DateTime? publishedOn;

  int authorId;

  /// Who wrote it.
  _ikaricya.Author? author;

  /// Returns a shallow copy of this [Book]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  Book copyWith({
    int? id,
    String? title,
    String? isbn,
    _ie1s4qve.BookFormat? format,
    int? priceInCents,
    int? stock,
    DateTime? publishedOn,
    int? authorId,
    _ikaricya.Author? author,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Book',
      if (id != null) 'id': id,
      'title': title,
      'isbn': isbn,
      'format': format.toJson(),
      'priceInCents': priceInCents,
      'stock': stock,
      if (publishedOn != null) 'publishedOn': publishedOn?.toJson(),
      'authorId': authorId,
      if (author != null) 'author': author?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Book',
      if (id != null) 'id': id,
      'title': title,
      'isbn': isbn,
      'format': format.toJson(),
      'priceInCents': priceInCents,
      'stock': stock,
      if (publishedOn != null) 'publishedOn': publishedOn?.toJson(),
      'authorId': authorId,
      if (author != null) 'author': author?.toJsonForProtocol(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BookImpl extends Book {
  _BookImpl({
    int? id,
    required String title,
    required String isbn,
    required _ie1s4qve.BookFormat format,
    required int priceInCents,
    int? stock,
    DateTime? publishedOn,
    required int authorId,
    _ikaricya.Author? author,
  }) : super._(
         id: id,
         title: title,
         isbn: isbn,
         format: format,
         priceInCents: priceInCents,
         stock: stock,
         publishedOn: publishedOn,
         authorId: authorId,
         author: author,
       );

  /// Returns a shallow copy of this [Book]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  Book copyWith({
    Object? id = _Undefined,
    String? title,
    String? isbn,
    _ie1s4qve.BookFormat? format,
    int? priceInCents,
    int? stock,
    Object? publishedOn = _Undefined,
    int? authorId,
    Object? author = _Undefined,
  }) {
    return Book(
      id: id is int? ? id : this.id,
      title: title ?? this.title,
      isbn: isbn ?? this.isbn,
      format: format ?? this.format,
      priceInCents: priceInCents ?? this.priceInCents,
      stock: stock ?? this.stock,
      publishedOn: publishedOn is DateTime? ? publishedOn : this.publishedOn,
      authorId: authorId ?? this.authorId,
      author: author is _ikaricya.Author? ? author : this.author?.copyWith(),
    );
  }
}
