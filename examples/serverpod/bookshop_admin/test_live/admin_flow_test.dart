// The admin's HTTP flow against a running bookshop_server.
//
// The same generated Client, the same serverpodBeakDataSource (Beak's
// HttpBeakDataSource over ServerpodBeakHttpClient) and the same session
// manager the admin uses (FlutterAuthSessionManager is this
// ClientAuthSessionManager plus a ValueNotifier), so everything below is what
// the panel's data layer does. It runs under `flutter test` because the data
// source is a Flutter-side type; no widget is pumped.
//
//   cd bookshop_server
//   # `dart run`, not `dart bin/main.dart`: only `dart run` builds the Argon2
//   # native asset the email login needs.
//   dart run bin/main.dart --apply-migrations > /tmp/bookshop.log 2>&1 &
//   cd ../bookshop_admin
//   BOOKSHOP_SERVER_LOG=/tmp/bookshop.log \
//     flutter test test_live/admin_flow_test.dart
//
// It lives outside test/ on purpose: `flutter test` must not need a server.
// BOOKSHOP_SERVER_URL (default http://localhost:8080/) and BOOKSHOP_SERVER_DIR
// (default ../bookshop_server) point it elsewhere.
@Timeout(Duration(minutes: 6))
library;

import 'dart:convert';
import 'dart:io';

import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod_flutter/beak_serverpod_flutter.dart'
    show BeakWireRequest, serverpodBeakDataSource;
import 'package:bookshop_beak/bookshop_beak.dart';
import 'package:bookshop_client/bookshop_client.dart' show Client;
import 'package:flutter_test/flutter_test.dart';
import 'package:postgres/postgres.dart';
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart';

final Map<String, String> _env = Platform.environment;
final String _serverUrl =
    _env['BOOKSHOP_SERVER_URL'] ?? 'http://localhost:8080/';
final File _serverLog = File(_env['BOOKSHOP_SERVER_LOG'] ?? 'server.log');
final String _serverDir = _env['BOOKSHOP_SERVER_DIR'] ?? '../bookshop_server';

final String _email =
    'moominmamma-${DateTime.now().millisecondsSinceEpoch}@dog-eared.test';
const String _password = 'Moomin-Troll-2026!';

final class _MemoryStorage implements ClientAuthSuccessStorage {
  AuthSuccess? _value;

  @override
  Future<AuthSuccess?> get() async => _value;

  @override
  Future<void> set(AuthSuccess? data) async => _value = data;
}

/// The verification code the server prints in development mode.
Future<String> _registrationCode(String email) async {
  final pattern = RegExp(
    'Registration code for ${RegExp.escape(email)}: <([A-Za-z0-9]+)>',
  );
  for (var i = 0; i < 100; i += 1) {
    final match = pattern.firstMatch(await _serverLog.readAsString());
    if (match != null) return match.group(1)!;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('No registration code for $email in ${_serverLog.path}.');
}

/// `bin/beak_admin.dart grant|revoke`, run next to the server.
Future<String> _beakAdmin(List<String> args) async {
  // `dart`, not Platform.resolvedExecutable: under `flutter test` that is the
  // flutter_tester binary.
  final result = await Process.run('dart', [
    'run',
    'bin/beak_admin.dart',
    ...args,
  ], workingDirectory: _serverDir);
  expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  return '${result.stdout}';
}

/// Serverpod's development database, over the unix socket its embedded
/// Postgres listens on (trust authentication, no password).
Future<Connection> _database() => Connection.open(
  Endpoint(
    host: File(
      '$_serverDir/.serverpod/development/run/.s.PGSQL.5432',
    ).resolveSymbolicLinksSync(),
    database: 'bookshop',
    username: 'postgres',
    isUnixSocket: true,
  ),
  settings: const ConnectionSettings(sslMode: SslMode.disable),
);

int _intId(BeakRecord record) => switch (record['id']?.raw) {
  final int id => id,
  final Object? other => throw StateError('no int id: $other'),
};

void main() {
  final sessionManager = ClientAuthSessionManager(storage: _MemoryStorage());
  final client = Client(_serverUrl)..authSessionManager = sessionManager;
  // The admin's data layer: Beak's stock HTTP data source over the tunnel.
  final source = serverpodBeakDataSource(client.beakAdmin.dispatch);
  Future<BeakPage<BeakRecord>> books() => source.query(
    const BookModel().query(
      relationLoads: [BeakRelationLoad(BookModel.author.key)],
    ),
  );

  test('an anonymous caller is refused by Serverpod with 401', () async {
    final anonymous = Client(_serverUrl);
    await expectLater(
      serverpodBeakDataSource(
        anonymous.beakAdmin.dispatch,
      ).query(const BookModel().query()),
      throwsA(isA<BeakAuthenticationException>()),
    );
    anonymous.close();
  });

  test('sign up by email (development: the code is in the log)', () async {
    final request = await client.emailIdp.startRegistration(email: _email);
    final token = await client.emailIdp.verifyRegistrationCode(
      accountRequestId: request,
      verificationCode: await _registrationCode(_email),
    );
    final auth = await client.emailIdp.finishRegistration(
      registrationToken: token,
      password: _password,
    );
    await sessionManager.updateSignedInUser(auth);
    expect(auth.scopeNames, isEmpty);
    expect(sessionManager.isAuthenticated, isTrue);
  });

  test('without beak.admin, Serverpod answers 403 before Beak runs', () async {
    await expectLater(books(), throwsA(isA<BeakAuthorizationException>()));
  });

  test(
    'grant with bin/beak_admin.dart (AuthServices), then sign in again',
    () async {
      final out = await _beakAdmin(['grant', _email]);
      printOnFailure(out);
      expect(out, contains('{} -> {beak.admin, bookshop.staff}'));
      // The token issued before the grant still carries no scopes.
      await expectLater(books(), throwsA(isA<BeakAuthorizationException>()));
      final auth = await client.emailIdp.login(
        email: _email,
        password: _password,
      );
      await sessionManager.updateSignedInUser(auth);
      expect(auth.scopeNames, {'beak.admin', 'bookshop.staff'});
    },
  );

  late int tove;
  late int moominland;

  test('create an author and books, edit one, filter by author', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    Future<int> author(String name) async => _intId(
      await source.create(
        const AuthorModel().table,
        BeakRecord(values: {'name': BeakStringValue(name)}),
      ),
    );
    Future<int> book(String title, String isbn, int author, int price) async =>
        _intId(
          await source.create(
            const BookModel().table,
            BeakRecord(
              values: {
                'title': BeakStringValue(title),
                'isbn': BeakStringValue(isbn),
                'format': const BeakStringValue('paperback'),
                'priceInCents': BeakIntValue(price),
                'stock': const BeakIntValue(20),
                'authorId': BeakIntValue(author),
              },
            ),
          ),
        );
    tove = await author('Tove Jansson');
    final ursula = await author('Ursula K. Le Guin');
    moominland = await book('Comet in Moominland', 'isbn-$stamp-1', tove, 1299);
    await book('Finn Family Moomintroll', 'isbn-$stamp-2', tove, 1199);
    await book('A Wizard of Earthsea', 'isbn-$stamp-3', ursula, 1499);

    // The panel's edit page reads the record by the id in the URL, which is a
    // string ("42"), and saves only what changed.
    final opened = await source.getOne(const BookModel().table, '$moominland');
    expect(opened?['title']?.raw, 'Comet in Moominland');
    final updated = await source.update(
      const BookModel().table,
      moominland,
      BeakRecord(
        values: {
          'title': const BeakStringValue('Comet in Moominland (revised)'),
          'priceInCents': const BeakIntValue(1399),
        },
      ),
    );
    expect(updated['title']?.raw, 'Comet in Moominland (revised)');
    expect(updated['priceInCents']?.raw, 1399);
    expect(updated['isbn']?.raw, 'isbn-$stamp-1', reason: 'untouched columns');

    // The panel's relation filter: BookModel.author.relationFilter().
    final page = await source.query(
      const BookModel().query(
        filter: BookModel.author.matches(AuthorModel.id.eq(tove)),
        relationLoads: [BeakRelationLoad(BookModel.author.key)],
      ),
    );
    expect(page.items.map((row) => row['title']?.raw).toSet(), {
      'Comet in Moominland (revised)',
      'Finn Family Moomintroll',
    });
    expect(
      page.items.map((row) => row.relations['author']?.single['name']?.raw),
      everyElement('Tove Jansson'),
    );
  });

  test('the form save is a graph commit: create, replay, edit', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    const draft = BeakRecordRef.draft('book', 'book');
    final createPlan = BeakSavePlan(
      saveId: 'live-create-$stamp',
      root: draft,
      operations: [
        BeakSaveOperation(
          id: 'book',
          kind: BeakSaveOperationKind.create,
          target: draft,
          values: BeakRecord(
            values: {
              'title': const BeakStringValue('Tales from Moominvalley'),
              'isbn': BeakStringValue('isbn-$stamp-commit'),
              'format': const BeakStringValue('hardcover'),
              'priceInCents': const BeakIntValue(1599),
              'stock': const BeakIntValue(5),
            },
          ),
          // BookModel.author.inputCombobox() picked this author.
          references: {'authorId': BeakRecordRef.existing('author', tove)},
        ),
      ],
    );
    final created = await source.commit(createPlan);
    expect(created.complete, isTrue);
    final bookId = _intId(created.rootRecord!);
    expect(created.rootRecord?['authorId']?.raw, tove);
    // A retried Save (same saveId) replays the receipt instead of inserting.
    final replay = await source.commit(createPlan);
    expect(_intId(replay.rootRecord!), bookId);

    final existing = BeakRecordRef.existing('book', bookId);
    final edited = await source.commit(
      BeakSavePlan(
        saveId: 'live-edit-$stamp',
        root: existing,
        operations: [
          BeakSaveOperation(
            id: 'book',
            kind: BeakSaveOperationKind.update,
            target: existing,
            values: BeakRecord(
              values: {'priceInCents': const BeakIntValue(1799)},
            ),
          ),
        ],
      ),
    );
    expect(edited.complete, isTrue);
    expect(edited.rootRecord?['priceInCents']?.raw, 1799);

    final stored = await source.getOne(const BookModel().table, '$bookId');
    expect(stored?['priceInCents']?.raw, 1799);
    expect(stored?['title']?.raw, 'Tales from Moominvalley');
    final byTove = await source.query(
      const BookModel().query(
        filter: BookModel.author.matches(AuthorModel.id.eq(tove)),
      ),
    );
    expect(
      byTove.items.where(
        (row) => row['title']?.raw == 'Tales from Moominvalley',
      ),
      hasLength(1),
      reason: 'the replay must not insert twice',
    );
  });

  test('the server-only supplier cost never leaves the server', () async {
    const marker = 7777777;
    final database = await _database();
    addTearDown(database.close);
    // Only the server can set it: here, straight in the database.
    await database.execute(
      Sql.named(
        'UPDATE "book" SET "supplierCostInCents" = @cost WHERE "id" = @id',
      ),
      parameters: {'cost': marker, 'id': moominland},
    );
    final stored = await database.execute(
      Sql.named('SELECT * FROM "book" WHERE "id" = @id'),
      parameters: {'id': moominland},
    );
    expect(
      stored.single.toColumnMap()['supplierCostInCents'],
      marker,
      reason: 'the value is in the row, so a SELECT * would leak it',
    );

    // The raw bytes the server sends back: no column, no key, no value.
    Future<String> raw(String method, String path, [Object? json]) async =>
        client.beakAdmin.dispatch(
          BeakWireRequest(
            method: method,
            path: path,
            query: '',
            headers: {if (json != null) 'content-type': 'application/json'},
            body: json == null ? '' : jsonEncode(json),
          ).encode(),
        );
    for (final reply in [
      await raw('GET', '/api/book/$moominland'),
      await raw('POST', '/api/book/query', const BookModel().query().toJson()),
      await raw('PATCH', '/api/book/$moominland', {'stock': 19}),
    ]) {
      expect(reply, contains('Comet in Moominland'));
      expect(reply, isNot(contains('supplierCost')));
      expect(reply, isNot(contains('$marker')));
    }

    // A graph commit that updates the row leaves the column untouched, and
    // the receipts it stores (plan and result) do not carry the value.
    final existing = BeakRecordRef.existing('book', moominland);
    final commit = await source.commit(
      BeakSavePlan(
        saveId: 'live-leak-${DateTime.now().microsecondsSinceEpoch}',
        root: existing,
        operations: [
          BeakSaveOperation(
            id: 'book',
            kind: BeakSaveOperationKind.update,
            target: existing,
            values: BeakRecord(values: {'stock': const BeakIntValue(18)}),
          ),
        ],
      ),
    );
    expect(commit.complete, isTrue);
    final receipts = await database.execute(
      'SELECT "requestJson", "resultJson" FROM "beak_commit_receipt"',
    );
    expect(receipts, isNotEmpty);
    for (final receipt in receipts) {
      final text = '${receipt[0]}${receipt[1]}';
      expect(text, isNot(contains('supplierCost')));
      expect(text, isNot(contains('$marker')));
    }
    final after = await database.execute(
      Sql.named(
        'SELECT "supplierCostInCents", "stock" FROM "book" WHERE "id" = @id',
      ),
      parameters: {'id': moominland},
    );
    expect(after.single[0], marker, reason: 'Beak writes never touch it');
    expect(after.single[1], 18);

    // And a client cannot write it: the column is not part of the model.
    await expectLater(
      source.update(
        const BookModel().table,
        moominland,
        BeakRecord(values: {'supplierCostInCents': const BeakIntValue(1)}),
      ),
      throwsA(isA<BeakValidationException>()),
    );
  });

  test('revoke takes both scopes away from the next sign-in', () async {
    final out = await _beakAdmin(['revoke', _email]);
    printOnFailure(out);
    expect(out, contains('{beak.admin, bookshop.staff} -> {}'));
    final auth = await client.emailIdp.login(
      email: _email,
      password: _password,
    );
    await sessionManager.updateSignedInUser(auth);
    expect(auth.scopeNames, isEmpty);
    await expectLater(books(), throwsA(isA<BeakAuthorizationException>()));
  });
}
