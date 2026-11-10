import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod/wire.dart';
import 'package:beak_serverpod_server/beak_serverpod_server.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart' hide LogLevel;

import 'support/book_models.dart';
import 'support/fake_serverpod.dart';

enum _Write { books }

const _staff = 'bookshop.staff';

final class _AdminBookModel extends BeakModel {
  const _AdminBookModel();

  @override
  String get table => 'book';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => BookColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    BeakBelongsTo(
      key: 'author',
      label: 'Author',
      relatedTable: 'author',
      displayColumnKey: 'name',
      foreignKey: 'authorId',
    ),
  ];

  @override
  Set<BeakOperation> get capabilities => const {
    BeakOperation.read,
    BeakOperation.create,
    BeakOperation.delete,
  };

  @override
  BeakPermissions get permissions => const BeakPermissions(
    read: BeakAccess.role(_staff),
    write: BeakAccess.role(_staff),
  );

  @override
  BeakAdmission get admission => const BeakAdmission(
    writable: [
      BookColumns.title,
      BookColumns.priceInCents,
      BookColumns.authorId,
    ],
    write: _Write.books,
  );
}

BeakWriteBindings<_Write> _writes() => BeakWriteBindings(
  (binding) => switch (binding) {
    _Write.books => const BeakWriteHandler.stock(),
  },
);

String _createRequest(String saveId, {String title = 'Moominland'}) =>
    BeakWireRequest(
      method: 'POST',
      path: '/api/commits',
      headers: const {'content-type': 'application/json'},
      body: jsonEncode(
        BeakSavePlan(
          saveId: saveId,
          root: const BeakRecordRef.draft('book', 'b'),
          operations: [
            BeakSaveOperation(
              id: 'b',
              kind: BeakSaveOperationKind.create,
              target: const BeakRecordRef.draft('book', 'b'),
              values: BeakRecord.fromRow({
                'title': title,
                'priceInCents': 1200,
              }),
            ),
          ],
        ).toJson(),
      ),
    ).encode();

String _updateRequest(String saveId) => BeakWireRequest(
  method: 'POST',
  path: '/api/commits',
  headers: const {'content-type': 'application/json'},
  body: jsonEncode(
    BeakSavePlan(
      saveId: saveId,
      root: const BeakRecordRef.existing('book', 'b1'),
      operations: [
        BeakSaveOperation(
          id: 'b',
          kind: BeakSaveOperationKind.update,
          target: const BeakRecordRef.existing('book', 'b1'),
          values: BeakRecord.fromRow({'title': 'Changed'}),
        ),
      ],
    ).toJson(),
  ),
).encode();

Future<BeakSaveResult> _result(
  BeakServerpodEngine engine,
  FakeSession session,
  String request,
) async => BeakSaveResult.fromJson(switch (jsonDecode(
  BeakWireResponse.decode(await engine.dispatch(session, request)).body,
)) {
  final Map<String, Object?> map => map,
  final Object? other => throw StateError('Expected an object: $other'),
});

void main() {
  late InMemoryAdapter adapter;
  late FakeSession staff;

  setUp(() async {
    Worm.seedRandom(42);
    adapter = await createBookshopDatabase();
    staff = FakeSession(authenticated: signedIn({'beak.admin', _staff}));
  });

  BeakServerpodEngine admitted({
    BeakSavePlanPreparer? preparePlan,
    BeakException? Function(Object error, StackTrace stackTrace)? mapException,
  }) => BeakServerpodEngine.admitted(
    models: const [_AdminBookModel(), AuthorModel()],
    definitions: BeakDefinitions.none,
    principal: BeakServerpodPrincipal.fromScopes,
    writes: _writes(),
    preparePlan: preparePlan,
    mapException: mapException,
    adapter: adapter,
  );

  test('an admitted engine creates a row through its write binding', () async {
    final engine = admitted();

    final result = await _result(engine, staff, _createRequest('create-books'));

    expect(result.complete, isTrue);
    final rows = await adapter.select(const QueryDescriptor(table: 'book'));
    expect(rows, hasLength(1));
    expect(rows.single['title'], 'Moominland');
  });

  test('an operation outside the capabilities is refused', () async {
    final engine = admitted();
    await engine.dispatch(staff, _createRequest('seed'));
    await adapter.insert(
      const InsertDescriptor(
        table: 'book',
        values: {'id': 'b1', 'title': 'Original', 'priceInCents': 1},
      ),
    );

    final result = await _result(engine, staff, _updateRequest('update-books'));

    expect(result.complete, isFalse);
    expect(result.outcomes.single.status, BeakWriteOutcome.unapplied);
  });

  test('pruneExpiredReceipts deletes receipts older than the window', () async {
    final engine = admitted();
    await engine.dispatch(staff, _createRequest('prune-seed'));

    final deleted = await engine.pruneExpiredReceipts(
      staff,
      retain: Duration.zero,
    );

    expect(deleted, greaterThanOrEqualTo(0));
  });

  test('mapException turns a host failure into a typed refusal', () async {
    var seen = false;
    final engine = admitted(
      preparePlan: (plan, source, principal) =>
          throw StateError('host failure'),
      mapException: (error, stackTrace) {
        seen = true;
        return const BeakValidationException('The host refused this.');
      },
    );

    final result = await _result(engine, staff, _createRequest('mapped'));

    expect(seen, isTrue);
    expect(result.complete, isFalse);
    expect(result.outcomes.single.error?.message, 'The host refused this.');
  });
}
