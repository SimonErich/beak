// ignore_for_file: cascade_invocations
//
// This test uses sequential `table.method(...)` calls to set up
// blueprint columns. Rewriting as cascades would harm readability
// for a 27-column type-coverage matrix.

import 'package:test/test.dart';
import 'package:worm/worm.dart';

void main() {
  group('Blueprint create', () {
    test('emits SQL with primary key, NOT NULL, defaults', () {
      final blueprint = Blueprint.create('users', (table) {
        table.idUuid();
        table.string('email').makeUnique();
        table.integer('age').makeNullable();
        table.boolean('active').withDefault(true);
      });
      final sql = blueprint.toSql();
      expect(sql, contains('CREATE TABLE "users"'));
      expect(sql, contains('"id" UUID'));
      expect(sql, contains('PRIMARY KEY'));
      expect(sql, contains('"email" VARCHAR(255)'));
      expect(sql, contains('UNIQUE'));
      expect(sql, contains('"age" INTEGER'));
      expect(sql, contains('"active" BOOLEAN'));
      expect(sql, contains('DEFAULT TRUE'));
    });

    test('emits MongoDB description with required flags', () {
      final blueprint = Blueprint.create('posts', (table) {
        table.uuid('id').primary();
        table.string('title');
        table.text('body').makeNullable();
      });
      final mongo = blueprint.toMongo();
      expect(mongo['operation'], 'create');
      expect(mongo['collection'], 'posts');
      final fields = mongo['fields']! as List<Map<String, Object?>>;
      expect(fields, hasLength(3));
      expect(fields[0]['bsonType'], 'string');
      expect(fields[1]['required'], true);
      expect(fields[2]['required'], false);
    });
  });

  group('Blueprint type coverage', () {
    test('all 24+ column types render valid SQL', () {
      final blueprint = Blueprint.create('all_types', (table) {
        table.string('a');
        table.smallInteger('b');
        table.integer('c');
        table.bigInteger('d');
        table.decimal('e');
        table.boolean('f');
        table.date('g');
        table.dateTime('h');
        table.uuid('i');
        table.json('j');
        table.jsonb('k');
        table.text('l');
        table.binary('m');
        table.doublePrecision('n');
        table.enumColumn('o', <String>['x', 'y']);
        table.tsvector('p');
        table.time('q');
        table.interval('r');
        table.inet('s');
        table.macaddr('t');
        table.point('u');
        table.line('v');
        table.box('w');
        table.money('x');
        table.bit('y');
        table.xml('z');
        table.array('aa', ColumnType.integer);
      });
      expect(blueprint.table.columns, hasLength(27));
      final sql = blueprint.toSql();
      expect(sql, contains('VARCHAR(255)'));
      expect(sql, contains('SMALLINT'));
      expect(sql, contains('NUMERIC(10,2)'));
      expect(sql, contains('INTEGER[]'));
    });
  });

  group('Blueprint alter and drop', () {
    test('alter adds columns and drops named columns', () {
      final blueprint = Blueprint.alter('users', (table) {
        table.string('bio');
        table.dropColumn('legacy');
      });
      final sql = blueprint.toSql();
      expect(sql, contains('ALTER TABLE "users"'));
      expect(sql, contains('ADD COLUMN'));
      expect(sql, contains('DROP COLUMN "legacy"'));
    });

    test('drop emits idempotent DROP TABLE', () {
      final sql = Blueprint.drop('users').toSql();
      expect(sql, 'DROP TABLE IF EXISTS "users";');
    });
  });

  group('Blueprint indexes and foreign keys', () {
    test('renders unique and partial indexes', () {
      final blueprint = Blueprint.create('users', (table) {
        table.uuid('id').primary();
        table.string('email');
        table.unique(<String>['email']);
        table.index(<String>['email'], where: 'email IS NOT NULL');
      });
      final sql = blueprint.toSql();
      expect(sql, contains('UNIQUE INDEX'));
      expect(sql, contains('WHERE email IS NOT NULL'));
    });

    test('renders foreign keys with ON DELETE action', () {
      final blueprint = Blueprint.create('posts', (table) {
        table.uuid('id').primary();
        table.uuid('user_id');
        table.foreign(
          column: 'user_id',
          references: 'id',
          onTable: 'users',
          onDelete: OnDelete.cascade,
        );
      });
      final sql = blueprint.toSql();
      expect(sql, contains('FOREIGN KEY ("user_id")'));
      expect(sql, contains('REFERENCES "users"("id")'));
      expect(sql, contains('ON DELETE CASCADE'));
    });
  });
}
