import 'package:beak_cli/src/cli_runner.dart';
import 'package:beak_cli/src/serverpod/generator.dart';
import 'package:test/test.dart';

import '../serverpod/serverpod_fixture.dart';

void main() {
  late ServerpodFixture fixture;

  setUp(() => fixture = ServerpodFixture());
  tearDown(() => fixture.delete());

  test('writes a definition class and beak generate accepts it', () async {
    fixture
      ..project()
      ..model('author', '''
### An author.
class: Author
table: author
fields:
  id: UuidValue
  ### The name.
  name: String
''')
      ..model('book', '''
### A book.
class: Book
table: book
fields:
  id: UuidValue
  ### The title.
  title: String
  stock: int
  author: Author?, relation(name=author_books, field=authorId)
''')
      ..database([
        ServerpodFixture.table('author', ['id', 'name']),
        ServerpodFixture.table('book', ['id', 'title', 'stock', 'authorId']),
      ])
      ..define('catalog/author', '''
@Resource()
@ServerpodModel(area: 'catalog', reason: 'Closed.')
final class Author extends BeakSchema {
  late final String name;
}''');

    final env = fixture.env();
    final code = await createBeakRunner(env).run(['make:definition', 'Book']);

    expect(code, 0, reason: env.out.toString());
    final source = fixture.read('definitions/lib/src/catalog/book.dart');
    expect(source, contains('/// A book.'));
    expect(source, contains('/// The title.'));
    expect(
      source,
      contains("reason: 'Read-only until its admin writes are opened.'"),
    );
    expect(source, contains("part 'book.beak.dart';"));
    expect(source, contains('@BelongsTo()'));
    expect(source, contains('late final Author? author;'));
    expect(source, contains('late final String title;'));
    expect(source, isNot(contains('/// The stock field.')));
    expect(
      source,
      contains("import 'package:shop_definitions/src/catalog/author.dart';"),
    );

    final result = runServerpodGenerate(fixture.env());
    expect(result.exitCode, 0);
    expect(
      fixture.exists('definitions/lib/src/catalog/book.beak.dart'),
      isTrue,
    );
  });

  test('refuses a relation whose target is not generated yet', () async {
    fixture
      ..project()
      ..model('author', '''
class: Author
table: author
fields:
  id: UuidValue
  name: String
''')
      ..model('book', '''
class: Book
table: book
fields:
  id: UuidValue
  title: String
  author: Author?, relation(field=authorId)
''')
      ..database([
        ServerpodFixture.table('author', ['id', 'name']),
        ServerpodFixture.table('book', ['id', 'title', 'authorId']),
      ])
      ..write('definitions/lib/src/catalog/.keep', '');

    final env = fixture.env();
    final code = await createBeakRunner(env).run(['make:definition', 'Book']);

    expect(code, 1);
    expect(env.out.toString(), contains('Generate Author first.'));
    expect(fixture.exists('definitions/lib/src/catalog/book.dart'), isFalse);
  });
}
