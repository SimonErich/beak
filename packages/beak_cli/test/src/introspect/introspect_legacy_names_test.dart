import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';

import '../../support/beak_cli_internals.dart';
import '../../support/fake_database.dart';

IntrospectedColumn _text(String name, {bool nullable = true}) =>
    IntrospectedColumn(name: name, dataType: 'text', isNullable: nullable);

const IntrospectedColumn _serialId = IntrospectedColumn(
  name: 'id',
  dataType: 'integer',
  isNullable: false,
  hasDefault: true,
);

IntrospectedTable _table(String name, List<IntrospectedColumn> columns) =>
    IntrospectedTable(name: name, columns: columns);

IntrospectedSchemaFile _emit(IntrospectedTable table) =>
    BeakIntrospectionEmitter.emitAll([table]).single;

void main() {
  group('a column named the way another tool names them', () {
    late IntrospectedSchemaFile file;

    setUp(() {
      file = _emit(
        _table('customers', [
          _serialId,
          _text('firstName', nullable: false),
          _text('address_line_1'),
          _text('Email'),
          _text('class'),
          const IntrospectedColumn(
            name: '2fa',
            dataType: 'integer',
            isNullable: true,
          ),
          _text('record'),
          _text('hashCode'),
          _text('last_name'),
        ]),
      );
    });

    test(
      'keeps the stored name where the field name would not give it back',
      () {
        // The reader derives a column's key from the field name, so a field the
        // database does not spell the same way has to name its column, or the
        // class reads and writes a column that is not there.
        expect(file.contents, contains("columnName: 'firstName'"));
        expect(file.contents, contains("columnName: 'address_line_1'"));
        expect(file.contents, contains("columnName: 'Email'"));
        expect(file.contents, contains('late final BeakText firstName;'));
        expect(file.contents, contains('late final BeakText? addressLine1;'));
        expect(file.contents, contains('late final BeakText? email;'));
      },
    );

    test('leaves a column the field name gives back alone', () {
      expect(file.contents, isNot(contains("columnName: 'last_name'")));
      expect(file.contents, contains('late final BeakText? lastName;'));
    });

    test('never declares a field the language cannot spell', () {
      // `class` and `2fa` used to reach the formatter and take the whole
      // command down with a syntax error; `record` is the name the typed
      // record view reserves.
      expect(file.contents, contains("columnName: 'class'"));
      expect(file.contents, contains('late final BeakText? classValue;'));
      expect(file.contents, contains("columnName: '2fa'"));
      expect(file.contents, contains('late final int? field2fa;'));
      expect(file.contents, contains("columnName: 'hashCode'"));
      expect(file.contents, contains('late final BeakText? hashCodeValue;'));
      expect(file.contents, contains("columnName: 'record'"));
      expect(file.contents, contains('late final BeakText? recordValue;'));
    });

    test('is read back as the column the database has', () {
      final root = Directory.systemTemp.createTempSync('beak_legacy_names_');
      addTearDown(() => root.deleteSync(recursive: true));
      File('${root.path}/lib/${file.path}')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(file.contents);

      final (schemas, issues) = BeakSchemaReader(root).read();

      expect(issues.map((issue) => issue.message), isEmpty);
      expect(
        schemas.single.columns.map((column) => column.columnKey),
        containsAll([
          'firstName',
          'address_line_1',
          'Email',
          'class',
          '2fa',
          'record',
          'last_name',
        ]),
      );
    });

    test('gives a foreign key to a table with an odd name its own column', () {
      const owner = IntrospectedTable(
        name: 'orders',
        columns: [
          _serialId,
          IntrospectedColumn(
            name: 'CustomerRef',
            dataType: 'integer',
            isNullable: false,
          ),
        ],
        foreignKeys: [
          IntrospectedForeignKey(
            column: 'CustomerRef',
            referencedTable: 'customers',
          ),
        ],
      );
      final emitted = BeakIntrospectionEmitter.emitAll([
        owner,
        _table('customers', [_serialId, _text('name')]),
      ]).firstWhere((emitted) => emitted.table == 'orders');

      expect(emitted.contents, contains("foreignKey: 'CustomerRef'"));
      expect(emitted.contents, contains('customerRef;'));
    });
  });

  group('a table named like something the generated code uses', () {
    test('gets a class of another name, and says which table it is', () {
      for (final (table, className) in const [
        ('lists', 'ListEntry'),
        ('strings', 'StringEntry'),
        ('resources', 'ResourceEntry'),
        ('columns', 'ColumnEntry'),
        ('schemas', 'SchemaEntry'),
        ('displays', 'DisplayEntry'),
        ('enums', 'EnumEntry'),
        ('date_times', 'DateTimeEntry'),
      ]) {
        expect(classNameOf(table), className, reason: table);
        final file = _emit(_table(table, [_serialId, _text('name')]));

        expect(file.className, className, reason: table);
        expect(file.contents, contains('final class $className extends'));
        expect(file.contents, contains("table: '$table'"), reason: table);
      }
    });

    test('keeps the plain name for a table that does not collide', () {
      expect(classNameOf('types'), 'Type');
      expect(classNameOf('objects'), 'Object');
      expect(classNameOf('order_items'), 'OrderItem');
    });

    test('is read back by prepare without an issue', () {
      final file = _emit(_table('resources', [_serialId, _text('name')]));
      final root = Directory.systemTemp.createTempSync('beak_reserved_');
      addTearDown(() => root.deleteSync(recursive: true));
      File('${root.path}/lib/${file.path}')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(file.contents);

      final (schemas, issues) = BeakSchemaReader(root).read();

      expect(issues.map((issue) => issue.message), isEmpty);
      expect(schemas.single.table, 'resources');
    });
  });

  group('a column with no letters or digits in its name', () {
    test('still gets a field, named for what it is', () {
      final file = _emit(_table('odd', [_serialId, _text('__'), _text('URL')]));

      expect(file.contents, contains("columnName: '__'"));
      expect(file.contents, contains('late final BeakText? field;'));
      expect(file.contents, contains("columnName: 'URL'"));
      expect(file.contents, contains('late final BeakText? url;'));
    });
  });

  group('two columns that spell one field', () {
    test('get a field each, the second numbered', () {
      final file = _emit(
        _table('people', [
          _serialId,
          _text('firstName'),
          _text('first_name'),
          _text('First Name'),
        ]),
      );

      expect(file.contents, contains('late final BeakText? firstName;'));
      expect(file.contents, contains('late final BeakText? firstName2;'));
      expect(file.contents, contains('late final BeakText? firstName3;'));
      expect(file.contents, contains("columnName: 'First Name'"));
    });

    test('leave a relationship the name it would have', () {
      const owner = IntrospectedTable(
        name: 'orders',
        columns: [
          _serialId,
          IntrospectedColumn(
            name: 'customer_id',
            dataType: 'integer',
            isNullable: true,
          ),
          IntrospectedColumn(
            name: 'customer',
            dataType: 'text',
            isNullable: true,
          ),
        ],
        foreignKeys: [
          IntrospectedForeignKey(
            column: 'customer_id',
            referencedTable: 'customers',
          ),
        ],
      );
      final emitted = BeakIntrospectionEmitter.emitAll([
        owner,
        _table('customers', [_serialId, _text('name')]),
      ]).firstWhere((emitted) => emitted.table == 'orders');

      expect(emitted.contents, contains('late final Customer? customer;'));
      expect(emitted.contents, contains('late final BeakText? customer2;'));
      expect(emitted.contents, contains("columnName: 'customer'"));
    });
  });

  group('a table with one of the two stamp columns', () {
    test('keeps it as a column of its own', () {
      final file = _emit(
        _table('events', [
          _serialId,
          _text('title'),
          const IntrospectedColumn(
            name: 'created_at',
            dataType: 'timestamp with time zone',
            isNullable: true,
          ),
        ]),
      );

      expect(file.contents, isNot(contains('timestamps: true')));
      expect(file.contents, contains('late final DateTime? createdAt;'));
    });

    test('with both leaves them to timestamps: true', () {
      final file = _emit(
        _table('events', [
          _serialId,
          _text('title'),
          const IntrospectedColumn(
            name: 'created_at',
            dataType: 'timestamp with time zone',
            isNullable: true,
          ),
          const IntrospectedColumn(
            name: 'updated_at',
            dataType: 'timestamp with time zone',
            isNullable: true,
          ),
        ]),
      );

      expect(file.contents, contains('timestamps: true'));
      expect(file.contents, isNot(contains('createdAt')));
    });
  });

  group('a column that holds a secret', () {
    test('is omitted whatever else the name says', () {
      final file = _emit(
        _table('accounts', [
          _serialId,
          _text('name'),
          _text('card_token'),
          _text('password_reset_token'),
          _text('passwordHash'),
          _text('api_secret'),
          _text('clientSecret'),
          _text('hashed_password'),
          _text('two_factor_secret'),
          _text('password_digest'),
          _text('private_key'),
          _text('stripe_api_key'),
        ]),
      );

      for (final omitted in [
        'cardToken',
        'passwordResetToken',
        'passwordHash',
        'apiSecret',
        'clientSecret',
        'hashedPassword',
        'twoFactorSecret',
        'passwordDigest',
        'privateKey',
        'stripeApiKey',
      ]) {
        expect(file.contents, isNot(contains(omitted)), reason: omitted);
      }
      expect(
        file.notes.where((note) => note.contains('secret')),
        hasLength(10),
      );
      expect(file.contents, contains('late final BeakText? name;'));
    });

    test('is told apart from a column that only resembles one', () {
      final file = _emit(
        _table('articles', [
          _serialId,
          _text('secretary'),
          _text('tokenizer'),
          _text('keyword'),
          _text('description'),
        ]),
      );

      expect(file.notes, isEmpty);
      expect(file.contents, contains('secretary'));
      expect(file.contents, contains('tokenizer'));
      expect(file.contents, contains('keyword'));
    });
  });

  group('a table whose primary key is not called id', () {
    test('says so, because Beak keys a record by id', () {
      final file = _emit(
        IntrospectedTable(
          name: 'things',
          columns: [_text('sku', nullable: false), _text('label')],
          primaryKey: 'sku',
        ),
      );

      final String note = file.notes.single;
      expect(note, contains('things'));
      expect(note, contains('sku'));
      expect(note, contains('`id`'));
    });

    test('stays quiet for the usual key', () {
      expect(
        _emit(_table('things', [_serialId, _text('label')])).notes,
        isEmpty,
      );
    });
  });

  group('reading a Postgres schema by another name', () {
    test('quotes the schema name in every query it interpolates it into', () {
      for (final sql in [
        PostgresIntrospector.columnsSql("a'b"),
        PostgresIntrospector.foreignKeysSql("a'b"),
        PostgresIntrospector.primaryKeysSql("a'b"),
        PostgresIntrospector.indexesSql("a'b"),
      ]) {
        expect(sql, contains("'a''b'"));
        expect(sql, isNot(contains("'a'b'")));
      }
    });
  });

  group('the introspect command', () {
    late Directory root;
    late StringBuffer out;

    setUp(() {
      root = Directory.systemTemp.createTempSync('beak_introspect_hard_');
      addTearDown(() => root.deleteSync(recursive: true));
      out = StringBuffer();
    });

    Future<int> run(
      List<String> args, {
      BeakLiveSchemaReader? readSchema,
    }) async {
      final runner = CommandRunner<int>('beak', 'test')
        ..addCommand(
          IntrospectCommand(
            BeakCliEnvironment(
              out: out,
              rootDirectory: root,
              now: () => DateTime.utc(2026),
              probe: (host, port) async => false,
            ),
            readSchema:
                readSchema ??
                (url, {String schema = 'public'}) =>
                    PostgresIntrospector(shopDatabase().query).read(),
          ),
        );
      return await runner.run(['introspect', ...args]) ?? 0;
    }

    test('does not create the SQLite file it was asked to read', () async {
      // Opening a SQLite path creates it, so a typo used to leave an empty
      // database in the project and report that it had no tables.
      expect(await run(['sqlite:nope.db']), 1);

      expect(File('${root.path}/nope.db').existsSync(), isFalse);
      expect(out.toString(), contains('nope.db'));
      expect(out.toString(), contains('no database'));
    });

    test(
      'says what went wrong instead of throwing when it cannot read',
      () async {
        final int exitCode = await run(
          ['postgres://u:secret-pw@localhost:1/shop'],
          readSchema: (url, {String schema = 'public'}) =>
              throw const SocketException('Connection refused'),
        );

        expect(exitCode, 1);
        expect(out.toString(), contains('Could not read the database schema'));
        expect(out.toString(), contains('Connection refused'));
        expect(out.toString(), isNot(contains('secret-pw')));
        expect(Directory('${root.path}/lib').existsSync(), isFalse);
      },
    );

    test('reads the SQLite file a path with .. names', () async {
      final Directory project = Directory('${root.path}/project')..createSync();
      File('${root.path}/legacy.db').createSync();
      Uri? read;
      final runner = CommandRunner<int>('beak', 'test')
        ..addCommand(
          IntrospectCommand(
            BeakCliEnvironment(
              out: out,
              rootDirectory: project,
              now: () => DateTime.utc(2026),
              probe: (host, port) async => false,
            ),
            readSchema: (url, {String schema = 'public'}) async {
              read = url;
              return PostgresIntrospector(shopDatabase().query).read();
            },
          ),
        );

      expect(await runner.run(['introspect', 'sqlite:../legacy.db']), 0);

      expect(beakSqliteFileOf(read!), '${root.path}/legacy.db');
    });

    test('refuses an --out that leaves the project', () async {
      for (final path in ['../elsewhere', '/tmp/beak_elsewhere', 'lib/../..']) {
        await expectLater(
          run([
            'postgres://u:p@localhost:5432/shop',
            '--ownership',
            'external',
            '--out',
            path,
          ]),
          throwsA(isA<UsageException>()),
          reason: path,
        );
      }
      expect(Directory('${root.path}/lib').existsSync(), isFalse);
    });

    test('writes a flat --out inside the project', () async {
      expect(
        await run([
          'postgres://u:p@localhost:5432/shop',
          '--ownership',
          'external',
          '--out',
          'tool/schema',
        ]),
        0,
      );

      expect(
        File('${root.path}/tool/schema/product.dart').existsSync(),
        isTrue,
      );
    });
  });
}
