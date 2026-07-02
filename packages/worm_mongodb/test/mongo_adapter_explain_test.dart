/// Unit tests for the MongoDB explain-response parser used by
/// [MongoAdapter.explain].
///
/// Drives [parseExplainOutput] directly with sample
/// `explain` command output captured from a real MongoDB 6.x
/// deployment. The parser is the only logic between the driver's
/// `runCommand` response and the [ExplainResult] returned by the
/// adapter — exercising it with sample JSON is equivalent to
/// invoking `explain()` against a mocked client returning the
/// same payload, without coupling the test to the mongo_dart
/// driver's command surface.
@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_mongodb/worm_mongodb.dart';

/// Sample plan for a COLLSCAN — no index satisfied the predicate,
/// so `totalKeysExamined` is `0`.
const Map<String, Object?> _collScanExplain = <String, Object?>{
  'queryPlanner': <String, Object?>{
    'plannerVersion': 1,
    'namespace': 'test.users',
    'winningPlan': <String, Object?>{
      'stage': 'COLLSCAN',
      'filter': <String, Object?>{'age': 25},
    },
  },
  'executionStats': <String, Object?>{
    'executionSuccess': true,
    'nReturned': 1,
    'executionTimeMillis': 0,
    'totalKeysExamined': 0,
    'totalDocsExamined': 100,
  },
  'ok': 1.0,
};

/// Sample plan for an IXSCAN — the planner used `users_email_idx`
/// and visited exactly one index key.
const Map<String, Object?> _indexScanExplain = <String, Object?>{
  'queryPlanner': <String, Object?>{
    'namespace': 'test.users',
    'winningPlan': <String, Object?>{
      'stage': 'IXSCAN',
      'indexName': 'users_email_idx',
    },
  },
  'executionStats': <String, Object?>{
    'executionSuccess': true,
    'nReturned': 1,
    'totalKeysExamined': 1,
    'totalDocsExamined': 1,
  },
  'ok': 1.0,
};

void main() {
  group('parseExplainOutput', () {
    test('flags COLLSCAN plans (totalKeysExamined == 0) as no index', () {
      final result = parseExplainOutput(_collScanExplain);
      expect(result.usesIndex, isFalse);
    });

    test('flags IXSCAN plans (totalKeysExamined > 0) as using an index', () {
      final result = parseExplainOutput(_indexScanExplain);
      expect(result.usesIndex, isTrue);
    });

    test('encodes the full explain document into raw', () {
      final result = parseExplainOutput(_indexScanExplain);
      expect(result.raw, isNotEmpty);
      expect(jsonDecode(result.raw), _indexScanExplain);
    });

    test('handles num-typed totalKeysExamined (driver may widen)', () {
      const explain = <String, Object?>{
        'executionStats': <String, Object?>{'totalKeysExamined': 3.0},
      };
      final result = parseExplainOutput(explain);
      expect(result.usesIndex, isTrue);
    });

    test('missing executionStats falls back to usesIndex=false', () {
      const explain = <String, Object?>{'queryPlanner': <String, Object?>{}};
      final result = parseExplainOutput(explain);
      expect(result.usesIndex, isFalse);
      expect(result.raw, isNotEmpty);
    });

    test('non-numeric totalKeysExamined falls back to usesIndex=false', () {
      const explain = <String, Object?>{
        'executionStats': <String, Object?>{'totalKeysExamined': 'invalid'},
      };
      final result = parseExplainOutput(explain);
      expect(result.usesIndex, isFalse);
    });

    test('returned object is a worm core ExplainResult', () {
      final result = parseExplainOutput(_collScanExplain);
      expect(result, isA<ExplainResult>());
    });
  });
}
