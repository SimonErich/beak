/// Unit tests for the EXPLAIN-result parser used by
/// [PostgresAdapter.explain].
///
/// Drives [parseExplainJsonOutput] directly with sample
/// `EXPLAIN (FORMAT JSON)` output captured from a real
/// PostgreSQL 16 server. The parser is the only logic between
/// the raw response and the [ExplainResult] returned by the
/// adapter — exercising it with sample JSON is equivalent to
/// invoking `explain()` against a connection mocked to return
/// the same payload, without coupling the test to the
/// postgres driver's internal result type.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_postgres/worm_postgres.dart';

const String _seqScanJson = '''
[
  {
    "Plan": {
      "Node Type": "Seq Scan",
      "Parallel Aware": false,
      "Relation Name": "users",
      "Alias": "users",
      "Startup Cost": 0.00,
      "Total Cost": 22.00,
      "Plan Rows": 1200,
      "Plan Width": 36
    }
  }
]''';

const String _indexScanJson = '''
[
  {
    "Plan": {
      "Node Type": "Index Scan",
      "Parallel Aware": false,
      "Scan Direction": "Forward",
      "Index Name": "users_email_idx",
      "Relation Name": "users",
      "Alias": "users",
      "Startup Cost": 0.42,
      "Total Cost": 8.44,
      "Plan Rows": 1,
      "Plan Width": 36,
      "Index Cond": "(email = 'a@b.c'::text)"
    }
  }
]''';

const String _nestedSeqScansJson = '''
[
  {
    "Plan": {
      "Node Type": "Hash Join",
      "Plans": [
        {"Node Type": "Seq Scan", "Relation Name": "orders"},
        {"Node Type": "Hash", "Plans": [
          {"Node Type": "Seq Scan", "Relation Name": "customers"}
        ]}
      ]
    }
  }
]''';

void main() {
  group('parseExplainJsonOutput', () {
    test('returns ExplainResult with the verbatim JSON as raw', () {
      final result = parseExplainJsonOutput(_seqScanJson);
      expect(result.raw, _seqScanJson);
      expect(result.raw, isNotEmpty);
    });

    test('flags Seq Scan plans as not using an index', () {
      final result = parseExplainJsonOutput(_seqScanJson);
      expect(result.usesIndex, isFalse);
      expect(result.scannedTables, <String>['users']);
    });

    test('flags Index Scan plans as using an index', () {
      final result = parseExplainJsonOutput(_indexScanJson);
      expect(result.usesIndex, isTrue);
      expect(result.scannedTables, isEmpty);
    });

    test('extracts every Seq Scan relation from a nested plan', () {
      final result = parseExplainJsonOutput(_nestedSeqScansJson);
      expect(result.usesIndex, isFalse);
      expect(result.scannedTables, <String>['orders', 'customers']);
    });

    test('empty plan still produces a valid ExplainResult', () {
      final result = parseExplainJsonOutput('');
      expect(result.raw, isEmpty);
      expect(result.usesIndex, isFalse);
      expect(result.scannedTables, isEmpty);
    });

    test('returned object is a worm core ExplainResult', () {
      final result = parseExplainJsonOutput(_indexScanJson);
      expect(result, isA<ExplainResult>());
    });
  });
}
