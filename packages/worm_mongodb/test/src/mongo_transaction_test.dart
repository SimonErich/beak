/// Transaction-capability tests for [MongoAdapter].
///
/// The `mongo_dart` driver has no client-session / transaction API,
/// so `MongoAdapter` reports `supportsTransactions: false` and
/// `transaction()` always throws [TransactionException] — it never
/// runs writes without isolation. These tests need no live server.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_mongodb/worm_mongodb.dart';

void main() {
  group('MongoAdapter transactions are unsupported', () {
    MongoAdapter buildAdapter() => MongoAdapter(
      connection: MongoConnection.fromUri('mongodb://localhost/x'),
    );

    test('capabilities report supportsTransactions: false', () {
      expect(buildAdapter().capabilities.supportsTransactions, isFalse);
    });

    test('transaction() throws TransactionException citing the driver', () {
      expect(
        () => buildAdapter().transaction((_) async => 1),
        throwsA(
          isA<TransactionException>().having(
            (e) => e.message,
            'message',
            contains('mongo_dart'),
          ),
        ),
      );
    });

    test('capability matrix declares no false claims (savepoints '
        'and joins unsupported; returning materially supported)', () {
      final capabilities = buildAdapter().capabilities;
      expect(capabilities.supportsSavepoints, isFalse);
      expect(capabilities.supportsJoins, isFalse);
      expect(capabilities.supportsReturning, isTrue);
    });
  });
}
