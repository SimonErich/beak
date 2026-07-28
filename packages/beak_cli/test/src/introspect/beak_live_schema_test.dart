import 'dart:io';

import 'package:beak_cli/beak_cli.dart';
import 'package:test/test.dart';

void main() {
  group('beakSqliteFileOf', () {
    test('reads the file a sqlite: URL names, in either shape', () {
      // `sqlite:beak.db` has no authority, so `Uri.path` is empty and the
      // whole string carries the name; `sqlite:///tmp/beak.db` has a path.
      expect(beakSqliteFileOf(Uri.parse('sqlite:beak.db')), 'beak.db');
      expect(
        beakSqliteFileOf(Uri.parse('sqlite:///tmp/beak.db')),
        '/tmp/beak.db',
      );
      expect(
        beakSqliteFileOf(Uri.parse('file:///tmp/beak.db')),
        '/tmp/beak.db',
      );
    });

    test('is null for an in-memory database', () {
      // It belongs to the process that opened it, so there is nothing for
      // another process to read.
      expect(beakSqliteFileOf(Uri.parse('sqlite::memory:')), isNull);
    });

    test('is null for a database that is not SQLite', () {
      expect(
        beakSqliteFileOf(Uri.parse('postgres://u:p@localhost:5432/beak')),
        isNull,
      );
    });
  });

  group('beakCanReadSchema', () {
    test('covers SQLite and Postgres, and says no to the rest', () {
      expect(beakCanReadSchema(Uri.parse('sqlite:beak.db')), isTrue);
      expect(
        beakCanReadSchema(Uri.parse('postgres://u:p@localhost:5432/beak')),
        isTrue,
      );
      expect(beakCanReadSchema(Uri.parse('mysql://localhost/beak')), isFalse);
      expect(beakCanReadSchema(Uri.parse('sqlite::memory:')), isFalse);
    });
  });

  group('beakResolvedDatabaseUrl', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('beak_url_');
      addTearDown(() => root.deleteSync(recursive: true));
    });

    test('makes a relative SQLite path absolute against the project', () {
      // `sqlite:beak.db` names a file beside the project, and the CLI runs
      // from wherever the user happens to be.
      expect(
        beakResolvedDatabaseUrl(Uri.parse('sqlite:beak.db'), root).toString(),
        'sqlite:${root.path}/beak.db',
      );
    });

    test('leaves an absolute path alone', () {
      expect(
        beakResolvedDatabaseUrl(Uri.parse('sqlite:///tmp/x.db'), root),
        Uri.parse('sqlite:///tmp/x.db'),
      );
    });

    test('leaves a server URL alone', () {
      final url = Uri.parse('postgres://u:p@localhost:5432/beak');
      expect(beakResolvedDatabaseUrl(url, root), url);
    });
  });

  group('beakSqliteFileExists', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('beak_url_');
      addTearDown(() => root.deleteSync(recursive: true));
    });

    test(
      'is false before the first migrate, and true after the file lands',
      () {
        final url = Uri.parse('sqlite:beak.db');
        expect(beakSqliteFileExists(url, root), isFalse);

        File('${root.path}/beak.db').writeAsStringSync('');
        expect(beakSqliteFileExists(url, root), isTrue);
      },
    );

    test('is false for a database that is not a file', () {
      expect(beakSqliteFileExists(Uri.parse('sqlite::memory:'), root), isFalse);
      expect(
        beakSqliteFileExists(Uri.parse('postgres://localhost/beak'), root),
        isFalse,
      );
    });
  });
}
