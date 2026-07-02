/// Unit tests for the MySQL `EXPLAIN FORMAT=JSON` plan parser.
///
/// These run without a database — they feed representative MySQL 8
/// plan documents to [parseMysqlExplainJson].
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:worm_mysql/worm_mysql.dart';

const String _fullScanPlan = '''
{
  "query_block": {
    "select_id": 1,
    "cost_info": {"query_cost": "1.25"},
    "table": {
      "table_name": "users",
      "access_type": "ALL",
      "rows_examined_per_scan": 5,
      "filtered": "20.00"
    }
  }
}
''';

const String _indexScanPlan = '''
{
  "query_block": {
    "select_id": 1,
    "table": {
      "table_name": "users",
      "access_type": "ref",
      "possible_keys": ["idx_users_email"],
      "key": "idx_users_email",
      "used_key_parts": ["email"],
      "rows_examined_per_scan": 1
    }
  }
}
''';

const String _joinPlan = '''
{
  "query_block": {
    "select_id": 1,
    "nested_loop": [
      {
        "table": {
          "table_name": "users",
          "access_type": "ALL",
          "rows_examined_per_scan": 5
        }
      },
      {
        "table": {
          "table_name": "posts",
          "access_type": "ref",
          "key": "idx_posts_user_id",
          "rows_examined_per_scan": 1
        }
      }
    ]
  }
}
''';

void main() {
  group('parseMysqlExplainJson', () {
    test('full table scan reports no index and the scanned table', () {
      final result = parseMysqlExplainJson(_fullScanPlan);
      expect(result.usesIndex, isFalse);
      expect(result.scannedTables, contains('users'));
      expect(result.raw, _fullScanPlan);
    });

    test('index ref scan reports index use and the chosen key', () {
      final result = parseMysqlExplainJson(_indexScanPlan);
      expect(result.usesIndex, isTrue);
      expect(result.indexName, 'idx_users_email');
      expect(result.scannedTables, isEmpty);
    });

    test('join with one full scan + one index scan uses an index', () {
      final result = parseMysqlExplainJson(_joinPlan);
      expect(result.usesIndex, isTrue);
      // Only the ALL-access table counts as a full scan.
      expect(result.scannedTables, <String>['users']);
    });

    test('empty plan text degrades gracefully', () {
      final result = parseMysqlExplainJson('');
      expect(result.usesIndex, isFalse);
      expect(result.scannedTables, isEmpty);
      expect(result.indexName, isNull);
    });
  });
}
