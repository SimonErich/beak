@TestOn('vm')
library;

import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

void main() {
  group('SqlitePreparedCache', () {
    late CommonDatabase db;

    setUp(() {
      db = sqlite3.openInMemory()..execute('CREATE TABLE t (id INTEGER)');
    });

    tearDown(() => db.close());

    test('caches by SQL: a repeat lookup returns the same statement', () {
      final cache = SqlitePreparedCache(db);
      final first = cache.statementFor('SELECT * FROM t');
      final second = cache.statementFor('SELECT * FROM t');
      expect(identical(first, second), isTrue);
      expect(cache.missCount, 1);
      expect(cache.hitCount, 1);
      expect(cache.missRate, closeTo(0.5, 1e-9));
      cache.clear();
    });

    test('evicts the least-recently-used entry at capacity', () {
      final cache = SqlitePreparedCache(db, maxSize: 2)
        ..statementFor('SELECT 1')
        ..statementFor('SELECT 2')
        // Touch '1' so '2' becomes LRU.
        ..statementFor('SELECT 1')
        ..statementFor('SELECT 3'); // evicts '2'
      expect(cache.length, 2);
      // '2' is a miss again (was evicted).
      final missesBefore = cache.missCount;
      cache.statementFor('SELECT 2');
      expect(cache.missCount, missesBefore + 1);
      cache.clear();
    });

    test('clear disposes statements and resets counters', () {
      final cache = SqlitePreparedCache(db)..statementFor('SELECT * FROM t');
      expect(cache.length, 1);
      cache.clear();
      expect(cache.length, 0);
      expect(cache.hitCount, 0);
      expect(cache.missCount, 0);
      expect(cache.missRate, 0);
    });
  });
}
