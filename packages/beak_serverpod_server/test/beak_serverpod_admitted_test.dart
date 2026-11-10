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

final class _Handlers implements BeakServerpodHandlers {
  const _Handlers({this.scopes = const []});

  @override
  BeakWriteBindings<_Write> get writes => BeakWriteBindings(
    (binding) => switch (binding) {
      _Write.books => const BeakWriteHandler.stock(),
    },
  );

  @override
  final List<BeakRowScope> scopes;
}

String _get(String path) => BeakWireRequest(
  method: 'GET',
  path: path,
  headers: const {'content-type': 'application/json'},
  body: '',
).encode();

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
    List<BeakRowScope> scopes = const [],
  }) => BeakServerpodEngine.admitted(
    models: const [_AdminBookModel(), AuthorModel()],
    principal: BeakServerpodPrincipal.fromScopes,
    handlers: _Handlers(scopes: scopes),
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

  test('a handler row scope narrows the list and opening a record', () async {
    final engine = admitted(
      scopes: [
        BeakRowScope(
          const _AdminBookModel(),
          (principal) => const BeakFieldFilter(
            column: BookColumns.title,
            operator: BeakOperator.eq,
            value: BeakStringValue('Kept'),
          ),
        ),
      ],
    );
    await engine.dispatch(staff, _createRequest('seed'));
    for (final (id, title) in [('b1', 'Kept'), ('b2', 'Hidden')]) {
      await adapter.insert(
        InsertDescriptor(
          table: 'book',
          values: {'id': id, 'title': title, 'priceInCents': 1},
        ),
      );
    }

    final list = BeakWireResponse.decode(
      await engine.dispatch(
        staff,
        BeakWireRequest(
          method: 'POST',
          path: '/api/book/query',
          headers: const {'content-type': 'application/json'},
          body: jsonEncode(const BeakQuerySpec(table: 'book').toJson()),
        ).encode(),
      ),
    );
    final hidden = BeakWireResponse.decode(
      await engine.dispatch(staff, _get('/api/book/b2')),
    );

    expect(list.body, contains('Kept'));
    expect(list.body, isNot(contains('Hidden')));
    expect(hidden.status, 404);
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
