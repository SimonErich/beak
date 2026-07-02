import 'package:test/test.dart';
import 'package:worm/worm.dart';

void main() {
  group('public API re-exports exceptions', () {
    test('WormException is accessible', () {
      const e = ModelNotFoundException(
        model: 'User',
        id: 1,
        message: 'not found',
      );
      expect(e, isA<WormException>());
    });

    test('all exception types are accessible', () {
      // Verify every type is importable from
      // package:worm/worm.dart.
      expect(
        const AdapterMismatchException(
          expectedAdapter: 'a',
          actualAdapter: 'b',
          message: 'm',
        ),
        isA<WormException>(),
      );
      expect(
        const CastException(
          field: 'f',
          fromType: 'a',
          toType: 'b',
          message: 'm',
        ),
        isA<WormException>(),
      );
      expect(
        const ConfigurationException(key: 'k', message: 'm'),
        isA<WormException>(),
      );
      expect(
        const ConnectionException(host: 'h', port: 0, message: 'm'),
        isA<WormException>(),
      );
      expect(
        const FullTableScanException(table: 't', message: 'm'),
        isA<WormException>(),
      );
      expect(
        const ForeignKeyException(table: 't', column: 'c', message: 'm'),
        isA<WormException>(),
      );
      expect(
        const MassAssignmentException(model: 'M', field: 'f', message: 'm'),
        isA<WormException>(),
      );
      expect(
        const MigrationException(migration: 'n', message: 'm'),
        isA<WormException>(),
      );
      expect(
        const QueryException(query: 'q', message: 'm'),
        isA<WormException>(),
      );
      expect(
        const RelationNotLoadedException(
          model: 'M',
          relationName: 'r',
          message: 'm',
        ),
        isA<WormException>(),
      );
      expect(const TransactionException(message: 'm'), isA<WormException>());
      expect(
        const UninitializedFieldException(model: 'M', field: 'f', message: 'm'),
        isA<WormException>(),
      );
      expect(
        const UniqueConstraintException(table: 't', column: 'c', message: 'm'),
        isA<WormException>(),
      );
      expect(
        const ValidationException(field: 'f', rule: 'r', message: 'm'),
        isA<WormException>(),
      );
    });
  });
}
