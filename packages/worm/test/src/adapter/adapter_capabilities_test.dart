import 'package:test/test.dart';
import 'package:worm/src/adapter/adapter_capabilities.dart';

void main() {
  group('AdapterCapabilities', () {
    test('default constructor produces all-false flags', () {
      const caps = AdapterCapabilities();
      expect(caps.supportsTransactions, isFalse);
      expect(caps.supportsSavepoints, isFalse);
      expect(caps.supportsStreaming, isFalse);
      expect(caps.supportsRawQuery, isFalse);
      expect(caps.supportsReturning, isFalse);
      expect(caps.supportsJoins, isFalse);
      expect(caps.supportsPreparedStatements, isFalse);
      expect(caps.supportsPartialIndexes, isFalse);
      expect(caps.supportsAggregations, isFalse);
      expect(caps.supportsSchemaIntrospection, isFalse);
      expect(caps.supportsExplain, isFalse);
    });

    test('is const constructible', () {
      const a = AdapterCapabilities();
      const b = AdapterCapabilities();
      expect(identical(a, b), isTrue);
    });

    test('each flag can be enabled independently without affecting others', () {
      const caps = AdapterCapabilities(supportsTransactions: true);
      expect(caps.supportsTransactions, isTrue);
      expect(caps.supportsSavepoints, isFalse);
      expect(caps.supportsStreaming, isFalse);
      expect(caps.supportsRawQuery, isFalse);
      expect(caps.supportsReturning, isFalse);
      expect(caps.supportsJoins, isFalse);
      expect(caps.supportsPreparedStatements, isFalse);
      expect(caps.supportsPartialIndexes, isFalse);
      expect(caps.supportsAggregations, isFalse);
      expect(caps.supportsSchemaIntrospection, isFalse);
      expect(caps.supportsExplain, isFalse);
    });

    test('every flag can be enabled in isolation', () {
      const pairs = <String, AdapterCapabilities>{
        'transactions': AdapterCapabilities(supportsTransactions: true),
        'savepoints': AdapterCapabilities(supportsSavepoints: true),
        'streaming': AdapterCapabilities(supportsStreaming: true),
        'rawQuery': AdapterCapabilities(supportsRawQuery: true),
        'returning': AdapterCapabilities(supportsReturning: true),
        'joins': AdapterCapabilities(supportsJoins: true),
        'preparedStatements': AdapterCapabilities(
          supportsPreparedStatements: true,
        ),
        'partialIndexes': AdapterCapabilities(supportsPartialIndexes: true),
        'aggregations': AdapterCapabilities(supportsAggregations: true),
        'schemaIntrospection': AdapterCapabilities(
          supportsSchemaIntrospection: true,
        ),
        'explain': AdapterCapabilities(supportsExplain: true),
      };

      for (final entry in pairs.entries) {
        expect(
          entry.value.supports(entry.key),
          isTrue,
          reason: '${entry.key} should report as supported',
        );
        // No other known key should report true for this instance.
        for (final otherKey in pairs.keys) {
          if (otherKey == entry.key) continue;
          expect(
            entry.value.supports(otherKey),
            isFalse,
            reason:
                'enabling ${entry.key} must not enable $otherKey '
                'via supports()',
          );
        }
      }
    });

    group('supports()', () {
      test('returns true for an enabled capability key', () {
        const caps = AdapterCapabilities(supportsTransactions: true);
        expect(caps.supports('transactions'), isTrue);
      });

      test('returns false for a disabled capability key', () {
        const caps = AdapterCapabilities();
        expect(caps.supports('transactions'), isFalse);
      });

      test('returns false for unknown keys and never throws', () {
        const caps = AdapterCapabilities();
        expect(caps.supports('unknown'), isFalse);
        expect(caps.supports(''), isFalse);
        expect(caps.supports('Transactions'), isFalse); // case-sensitive
        expect(caps.supports('supports_transactions'), isFalse);
      });

      test('recognises every capability key', () {
        const caps = AdapterCapabilities(
          supportsTransactions: true,
          supportsSavepoints: true,
          supportsStreaming: true,
          supportsRawQuery: true,
          supportsReturning: true,
          supportsJoins: true,
          supportsPreparedStatements: true,
          supportsPartialIndexes: true,
          supportsAggregations: true,
          supportsSchemaIntrospection: true,
          supportsExplain: true,
        );
        const keys = <String>[
          'transactions',
          'savepoints',
          'streaming',
          'rawQuery',
          'returning',
          'joins',
          'preparedStatements',
          'partialIndexes',
          'aggregations',
          'schemaIntrospection',
          'explain',
        ];
        for (final key in keys) {
          expect(caps.supports(key), isTrue, reason: 'supports("$key")');
        }
      });
    });

    test('copyWith overrides only selected flags', () {
      const original = AdapterCapabilities(
        supportsTransactions: true,
        supportsStreaming: true,
      );
      final copy = original.copyWith(supportsTransactions: false);
      expect(copy.supportsTransactions, isFalse);
      expect(copy.supportsStreaming, isTrue); // untouched
      expect(copy.supportsJoins, isFalse); // untouched
    });
  });
}
