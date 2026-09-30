import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod/beak_serverpod.dart';
import 'package:test/test.dart';

void main() {
  test('the bookshop resource binds every operation', () async {
    final books = BookEndpoint([_dune]);
    final source = ServerpodDataSource(resources: [bookResource(books)]);

    final page = await source.query(
      const BeakQuerySpec(table: 'books').paginate(page: 1, perPage: 20),
    );
    expect(page.total, 1);
    expect(page.items.single['title']?.raw, 'Dune');
    expect(books.lastPage, (page: 0, perPage: 20));

    Book emma({int priceInCents = 899}) => Book(
      title: 'Emma',
      isbn: '978-0141439587',
      format: BookFormat.ebook,
      priceInCents: priceInCents,
      stock: 3,
      authorId: 1,
    );
    const codec = BookCodec();
    final created = await source.create('books', codec.encode(emma()));
    expect(created['id']?.raw, 2);
    expect((await source.getOne('books', 2))?['title']?.raw, 'Emma');

    await source.update('books', 2, codec.encode(emma(priceInCents: 999)));
    expect(books.rows[2]?.priceInCents, 999);

    await source.delete('books', 2);
    expect(books.archived, {2});
    await source.delete('books', 2, force: true);
    expect(books.rows.containsKey(2), isFalse);
    expect((await source.batchGet('books', [1])).single['id']?.raw, 1);
    expect(
      await source.aggregate(const BeakAggregateSpec.count(table: 'books')),
      1,
    );
    expect(
      source.binding('books').operations,
      ServerpodOperation.values.toSet(),
    );
  });

  test('a range filter is refused, not translated', () async {
    final source = ServerpodDataSource(
      resources: [
        bookResource(BookEndpoint([_dune])),
      ],
    );
    final spec = const BeakQuerySpec(table: 'books').withFilter(
      BeakFieldFilter.forKey(
        'priceInCents',
        BeakOperator.gt,
        BeakValue.of(500),
      ),
    );
    await expectLater(
      source.query(spec),
      throwsA(isA<BeakConfigurationException>()),
    );
  });
}

final _dune = Book(
  id: 1,
  title: 'Dune',
  isbn: '978-0441172719',
  format: BookFormat.paperback,
  priceInCents: 1299,
  authorId: 1,
);

/// Stand-in for the generated `BookFormat`.
enum BookFormat { paperback, hardcover, ebook }

/// Stand-in for the generated `Book` in `bookshop_client`.
final class Book {
  Book({
    this.id,
    required this.title,
    required this.isbn,
    required this.format,
    required this.priceInCents,
    this.stock = 0,
    required this.authorId,
  });

  int? id;
  String title;
  String isbn;
  BookFormat format;
  int priceInCents;
  int stock;
  int authorId;

  Book copyWith({int? id, int? priceInCents}) => Book(
    id: id ?? this.id,
    title: title,
    isbn: isbn,
    format: format,
    priceInCents: priceInCents ?? this.priceInCents,
    stock: stock,
    authorId: authorId,
  );
}

/// Stand-in for the endpoint a Serverpod project exposes as `client.books`.
final class BookEndpoint {
  BookEndpoint(Iterable<Book> initial)
    : rows = {for (final book in initial) book.id!: book};

  final Map<int, Book> rows;
  final Set<int> archived = {};
  ({int page, int perPage})? lastPage;

  Future<({List<Book> rows, int total})> list({
    required int page,
    required int perPage,
  }) async {
    lastPage = (page: page, perPage: perPage);
    return (rows: rows.values.toList(), total: rows.length);
  }

  Future<Book?> get(int id) async => rows[id];

  Future<Book> save(Book book) async {
    final saved = book.copyWith(id: book.id ?? rows.length + 1);
    rows[saved.id!] = saved;
    return saved;
  }

  Future<void> archive(int id) async => archived.add(id);

  Future<void> delete(int id) async => rows.remove(id);

  Future<Book> unarchive(int id) async {
    archived.remove(id);
    return rows[id]!;
  }

  Future<List<Book>> getMany(List<int> ids) async => [
    for (final id in ids)
      if (rows[id] != null) rows[id]!,
  ];

  Future<int> count() async => rows.length;
}

// --8<-- [start:bookModel]
const _id = BeakIntColumn(key: 'id', label: 'ID');
const _title = BeakStringColumn(key: 'title', label: 'Title');

const bookModel = ServerpodModel(
  resource: 'books',
  columns: [
    _id,
    _title,
    BeakStringColumn(key: 'isbn', label: 'ISBN'),
    BeakEnumColumn<BookFormat>(
      key: 'format',
      label: 'Format',
      values: BookFormat.values,
    ),
    BeakIntColumn(key: 'priceInCents', label: 'Price in cents'),
    BeakIntColumn(key: 'stock', label: 'Stock'),
    BeakIntColumn(key: 'authorId', label: 'Author'),
  ],
  primaryKey: _id,
  displayColumn: _title,
);
// --8<-- [end:bookModel]

// --8<-- [start:bookCodec]
final class BookCodec extends ServerpodCodec<Book> {
  const BookCodec();

  static final _format = ServerpodCodecs.enumeration(BookFormat.values);

  @override
  BeakRecord encode(Book book) => BeakRecord(
    values: {
      'id': ServerpodCodecs.integer.nullable.encode(book.id),
      'title': ServerpodCodecs.string.encode(book.title),
      'isbn': ServerpodCodecs.string.encode(book.isbn),
      'format': _format.encode(book.format),
      'priceInCents': ServerpodCodecs.integer.encode(book.priceInCents),
      'stock': ServerpodCodecs.integer.encode(book.stock),
      'authorId': ServerpodCodecs.integer.encode(book.authorId),
    },
  );

  @override
  Book decode(BeakRecord record) => Book(
    id: ServerpodCodecs.integer.nullable.decode(record['id']),
    title: ServerpodCodecs.string.decode(record['title']),
    isbn: ServerpodCodecs.string.decode(record['isbn']),
    format: _format.decode(record['format']),
    priceInCents: ServerpodCodecs.integer.decode(record['priceInCents']),
    stock: ServerpodCodecs.integer.decode(record['stock']),
    authorId: ServerpodCodecs.integer.decode(record['authorId']),
  );
}
// --8<-- [end:bookCodec]

// --8<-- [start:bookResource]
ServerpodResource<Book, int, Book, Book> bookResource(BookEndpoint books) =>
    ServerpodResource<Book, int, Book, Book>(
      model: bookModel,
      codec: const BookCodec(),
      idCodec: ServerpodCodecs.integer,
      identify: (book) => book.id!,
      query: (spec) async {
        final reader = ServerpodQueryReader(
          spec: spec,
          model: bookModel,
          fields: const {},
        );
        final result = await books.list(
          page: reader.page(0),
          perPage: reader.perPage,
        );
        return BeakPage(
          items: result.rows,
          total: result.total,
          page: spec.pagination.page,
          perPage: reader.perPage,
        );
      },
      get: books.get,
      createCodec: const BookCodec(),
      create: books.save,
      updateCodec: const BookCodec(),
      update: (id, input) => books.save(input.copyWith(id: id)),
      editValues: (book) => book,
      archive: books.archive,
      forceDelete: books.delete,
      restore: books.unarchive,
      batchGet: books.getMany,
      aggregate: (spec) async => books.count(),
    );
// --8<-- [end:bookResource]
