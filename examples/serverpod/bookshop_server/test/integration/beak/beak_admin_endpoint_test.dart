import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod/wire.dart';
import 'package:beak_serverpod_server/beak_serverpod_server.dart';
import 'package:bookshop_beak/bookshop_beak.dart';
import 'package:bookshop_server/src/beak/bookshop_scopes.dart';
import 'package:bookshop_server/src/generated/protocol.dart' as sp;
import 'package:serverpod/serverpod.dart' show Scope;
import 'package:test/test.dart';

import '../test_tools/serverpod_test_tools.dart';
import 'support/catalog_fixture.dart';
import 'support/raw_tunnel.dart';

const _staffId = '0192f5a4-9a2e-7c3a-8f1e-3b1a2c4d5e71';

/// An envelope Beak itself answers with 400: a caller that gets Serverpod's
/// exception for it instead never reached Beak.
const String _malformed = 'this is not an envelope';

Map<String, Object?> _json(BeakWireResponse response) =>
    switch (jsonDecode(response.body)) {
      final Map<String, Object?> map => map,
      final Object? other => fail('not a JSON object: $other'),
    };

int _idOf(BeakWireResponse response) =>
    switch (BeakRecord.fromJson(_json(response))['id']?.raw) {
      final int id => id,
      final Object? other => fail('no int id in ${response.body} ($other)'),
    };

BeakSavePlan _createBookPlan(String saveId, {required int authorId}) {
  const draft = BeakRecordRef.draft('book', 'book');
  return BeakSavePlan(
    saveId: saveId,
    root: draft,
    operations: [
      BeakSaveOperation(
        id: 'book',
        kind: BeakSaveOperationKind.create,
        target: draft,
        values: BeakRecord(
          values: {
            'title': const BeakStringValue('Tales from Moominvalley'),
            'isbn': BeakStringValue('isbn-$saveId'),
            'format': const BeakStringValue('hardcover'),
            'priceInCents': const BeakIntValue(1599),
            'stock': const BeakIntValue(5),
          },
        ),
        references: {'authorId': BeakRecordRef.existing('author', authorId)},
      ),
    ],
  );
}

/// The admin tunnel through Serverpod's real endpoint dispatch: the
/// `BeakAdminGate` mixin, the engine, the session adapter and Serverpod's own
/// Postgres.
void main() {
  withServerpod('Given the Beak admin endpoint', (sessionBuilder, endpoints) {
    TestSessionBuilder signedIn(Set<Scope> scopes) => sessionBuilder.copyWith(
      authentication: AuthenticationOverride.authenticationInfo(
        _staffId,
        scopes,
      ),
    );
    RawTunnel tunnel(TestSessionBuilder session) =>
        RawTunnel((request) => endpoints.beakAdmin.dispatch(session, request));

    final staff = tunnel(signedIn({BeakScopes.admin, BookshopScopes.staff}));
    final gateOnly = tunnel(signedIn({BeakScopes.admin}));
    late Catalog catalog;

    setUp(() async {
      catalog = await Catalog.seed(sessionBuilder.build());
    });

    int bookId() => catalog.books.first.id!;

    group('the Serverpod gate answers before Beak runs', () {
      test('anonymous: 401', () async {
        await expectLater(
          endpoints.beakAdmin.dispatch(sessionBuilder, _malformed),
          throwsA(isA<ServerpodUnauthenticatedException>()),
        );
      });

      test('signed in without beak.admin: 403, even with every other scope '
          'including serverpod.admin', () async {
        for (final scopes in [
          <Scope>{},
          {BookshopScopes.staff},
          {Scope.admin, BookshopScopes.staff},
        ]) {
          await expectLater(
            endpoints.beakAdmin.dispatch(signedIn(scopes), _malformed),
            throwsA(isA<ServerpodInsufficientAccessException>()),
            reason: '$scopes',
          );
        }
      });

      test('with beak.admin the same envelope reaches Beak: 400', () async {
        final reply = await endpoints.beakAdmin.dispatch(
          signedIn({BeakScopes.admin}),
          _malformed,
        );
        expect(BeakWireResponse.decode(reply).status, 400);
      });
    });

    group('the policy is deny by default', () {
      test('beak.admin alone opens the tunnel but grants nothing', () async {
        for (final (method, path, json) in [
          ('GET', '/api/book/${bookId()}', null),
          ('POST', '/api/book/query', const <String, Object?>{}),
          ('POST', '/api/author/query', const <String, Object?>{}),
          ('PATCH', '/api/book/${bookId()}', const {'stock': 1}),
        ]) {
          final reply = await gateOnly.call(method, path, json: json);
          expect(reply.status, 403, reason: '$method $path ${reply.body}');
          expect(_json(reply)['code'], 'authorization');
        }
        final book = await sp.Book.db.findById(
          sessionBuilder.build(),
          bookId(),
        );
        expect(book?.stock, 5);
      });

      test('staff read and write, but nobody deletes', () async {
        expect((await staff.call('GET', '/api/book/${bookId()}')).status, 200);
        expect(
          (await staff.call(
            'PATCH',
            '/api/book/${bookId()}',
            json: {'stock': 3},
          )).status,
          200,
        );
        final delete = await staff.call('DELETE', '/api/book/${bookId()}');
        expect(delete.status, 403, reason: delete.body);
        expect(
          await sp.Book.db.findById(sessionBuilder.build(), bookId()),
          isNotNull,
        );
      });

      test('a table Beak does not register is not there at all', () async {
        for (final table in [
          'serverpod_auth_core_user',
          'serverpod_auth_core_jwt_refresh_token',
          'beak_commit_receipt',
        ]) {
          final reply = await staff.call(
            'POST',
            '/api/$table/query',
            json: const <String, Object?>{},
          );
          expect(reply.status, 404, reason: '$table ${reply.body}');
        }
      });
    });

    group('authors and books through the tunnel, on Serverpod\'s database', () {
      test('create an author and a book, then update and filter', () async {
        final author = await staff.call(
          'POST',
          '/api/author',
          json: {'name': 'Astrid Lindgren', 'bio': 'Pippi'},
        );
        expect(author.status, 201, reason: author.body);
        final authorId = _idOf(author);

        final book = await staff.call(
          'POST',
          '/api/book',
          json: {
            'title': 'Pippi Longstocking',
            'isbn': '978-0-19-000000-1',
            'format': 'hardcover',
            'priceInCents': 1999,
            'stock': 4,
            'authorId': authorId,
          },
        );
        expect(book.status, 201, reason: book.body);
        final bookId = _idOf(book);

        final updated = await staff.call(
          'PATCH',
          '/api/book/$bookId',
          json: {
            'title': 'Pippi Longstocking (revised)',
            'priceInCents': 2099,
          },
        );
        expect(updated.status, 200, reason: updated.body);

        // Serverpod's typed ORM sees exactly what Beak wrote.
        final stored = await sp.Book.db.findById(
          sessionBuilder.build(),
          bookId,
        );
        expect(stored?.title, 'Pippi Longstocking (revised)');
        expect(stored?.priceInCents, 2099);
        expect(stored?.format, sp.BookFormat.hardcover);
        expect(stored?.authorId, authorId);
        expect(stored?.isbn, '978-0-19-000000-1', reason: 'untouched column');

        // BookModel.author.relationFilter(), with the author loaded eagerly.
        final page = await staff.call(
          'POST',
          '/api/book/query',
          json: const BookModel()
              .query(
                filter: BookModel.author.matches(
                  AuthorModel.id.eq(catalog.tove.id!),
                ),
                relationLoads: [BeakRelationLoad(BookModel.author.key)],
              )
              .toJson(),
        );
        expect(page.status, 200, reason: page.body);
        final titles = [
          for (final item in _json(page)['items']! as List<Object?>)
            if (item case {'values': {'title': final String title}}) title,
        ];
        expect(
          titles,
          unorderedEquals([
            'Comet in Moominland',
            'Finn Family Moomintroll',
          ]),
        );
        expect(page.body, contains('Tove Jansson'));
        expect(page.body, isNot(contains('Ursula')));
      });

      test('an ISBN that already exists is a validation error, not a 500 or a '
          'second row', () async {
        final duplicate = await staff.call(
          'POST',
          '/api/book',
          json: {
            'title': 'Comet again',
            'isbn': catalog.books.first.isbn,
            'format': 'ebook',
            'priceInCents': 100,
            'stock': 1,
            'authorId': catalog.tove.id,
          },
        );
        expect(duplicate.status, anyOf(409, 422), reason: duplicate.body);
        expect(await sp.Book.db.count(sessionBuilder.build()), 3);
      });
    });

    group('the form save is a graph commit', () {
      test('creates once, replays by saveId, and keeps a receipt', () async {
        final plan = _createBookPlan(
          'save-1',
          authorId: catalog.tove.id!,
        ).toJson();
        final first = await staff.call('POST', '/api/commits', json: plan);
        expect(first.status, 200, reason: first.body);
        final created = BeakSaveResult.fromJson(_json(first));
        expect(created.complete, isTrue);
        final bookId = created.rootRecord?['id']?.raw;
        expect(bookId, isA<int>());

        final replay = await staff.call('POST', '/api/commits', json: plan);
        final replayed = BeakSaveResult.fromJson(_json(replay));
        expect(replayed.rootRecord?['id']?.raw, bookId);
        expect(
          await sp.Book.db.count(
            sessionBuilder.build(),
            where: (t) => t.isbn.equals('isbn-save-1'),
          ),
          1,
          reason: 'the replay must not insert twice',
        );

        // Beak's receipts live in the Serverpod-owned table.
        final receipts = await sp.BeakCommitReceipt.db.find(
          sessionBuilder.build(),
        );
        expect(receipts, hasLength(1));
      });

      test('receipts age out through the typed model, by createdAt', () async {
        final plan = _createBookPlan(
          'save-old',
          authorId: catalog.tove.id!,
        ).toJson();
        await staff.call('POST', '/api/commits', json: plan);
        final session = sessionBuilder.build();
        final receipt = (await sp.BeakCommitReceipt.db.find(session)).single;
        await sp.BeakCommitReceipt.db.updateRow(
          session,
          receipt.copyWith(
            createdAt: DateTime.now().toUtc().subtract(
              const Duration(days: 60),
            ),
          ),
        );
        await staff.call(
          'POST',
          '/api/commits',
          json: _createBookPlan(
            'save-new',
            authorId: catalog.tove.id!,
          ).toJson(),
        );

        final cutoff = DateTime.now().toUtc().subtract(
          const Duration(days: 30),
        );
        final pruned = await sp.BeakCommitReceipt.db.deleteWhere(
          session,
          where: (t) => t.createdAt < cutoff,
        );

        expect(pruned.map((row) => row.id), [receipt.id]);
        final kept = await sp.BeakCommitReceipt.db.find(session);
        expect(kept, hasLength(1));
        expect(kept.single.id, isNot(receipt.id));
      });
    });
  });
}
