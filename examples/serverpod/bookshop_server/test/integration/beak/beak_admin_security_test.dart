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

Map<String, Object?> _json(BeakWireResponse response) =>
    switch (jsonDecode(response.body)) {
      final Map<String, Object?> map => map,
      final Object? other => fail('not a JSON object: $other'),
    };

/// What the tunnel must keep in and out of the browser's reach: the
/// server-only supplier cost never travels, and a client cannot write it.
void main() {
  withServerpod('Given a book with a server-only supplier cost', (
    sessionBuilder,
    endpoints,
  ) {
    TestSessionBuilder signedIn(Set<Scope> scopes) => sessionBuilder.copyWith(
      authentication: AuthenticationOverride.authenticationInfo(
        _staffId,
        scopes,
      ),
    );
    RawTunnel tunnel(TestSessionBuilder session) =>
        RawTunnel((request) => endpoints.beakAdmin.dispatch(session, request));

    final staff = tunnel(signedIn({BeakScopes.admin, BookshopScopes.staff}));
    late Catalog catalog;

    setUp(() async {
      catalog = await Catalog.seed(sessionBuilder.build());
    });

    int bookId() => catalog.books.first.id!;

    Future<int?> storedSupplierCost() async => (await sp.Book.db.findById(
      sessionBuilder.build(),
      bookId(),
    ))?.supplierCostInCents;

    BeakSavePlan updatePlan(String saveId, Map<String, BeakValue> values) {
      final existing = BeakRecordRef.existing('book', bookId());
      return BeakSavePlan(
        saveId: saveId,
        root: existing,
        operations: [
          BeakSaveOperation(
            id: 'book',
            kind: BeakSaveOperationKind.update,
            target: existing,
            values: BeakRecord(values: values),
          ),
        ],
      );
    }

    group('the value never leaves the server', () {
      test('the fixture really stores it (a SELECT * would leak it)', () async {
        final rows = await sessionBuilder.build().db.unsafeQuery(
          'SELECT * FROM "book" WHERE "id" = ${bookId()}',
        );
        expect(
          leaksIn(jsonEncode([for (final row in rows) row.toColumnMap()])),
          isNotEmpty,
        );
      });

      test('not in any read, write or graph commit response, and not in a '
          'receipt', () async {
        final replies = <String, BeakWireResponse>{
          'list': await staff.call(
            'POST',
            '/api/book/query',
            json: const BookModel()
                .query(relationLoads: [BeakRelationLoad(BookModel.author.key)])
                .toJson(),
          ),
          'author with books': await staff.call(
            'POST',
            '/api/author/query',
            json: const AuthorModel()
                .query(relationLoads: [BeakRelationLoad('books')])
                .toJson(),
          ),
          'one': await staff.call('GET', '/api/book/${bookId()}'),
          'batch': await staff.call(
            'POST',
            '/api/book/batch',
            json: {
              'ids': [bookId()],
            },
          ),
          'patch': await staff.call(
            'PATCH',
            '/api/book/${bookId()}',
            json: {'stock': 2},
          ),
          'commit': await staff.call(
            'POST',
            '/api/commits',
            json: updatePlan('leak-1', {
              'priceInCents': const BeakIntValue(1777),
            }).toJson(),
          ),
        };
        for (final MapEntry(:key, :value) in replies.entries) {
          expect(value.status, 200, reason: '$key ${value.body}');
          expect(leaksIn(value.body), isEmpty, reason: '$key ${value.body}');
          expect(
            leaksIn(jsonEncode(value.headers)),
            isEmpty,
            reason: '$key headers',
          );
        }
        // The list really returned the books it was supposed to hide the cost
        // of, and the update touched the row without clearing the column.
        expect(replies['list']!.body, contains('Comet in Moominland'));
        expect(await storedSupplierCost(), leakSupplierCostInCents);

        final receipts = await sp.BeakCommitReceipt.db.find(
          sessionBuilder.build(),
        );
        expect(receipts, isNotEmpty);
        for (final receipt in receipts) {
          expect(
            leaksIn('${receipt.requestJson}${receipt.resultJson}'),
            isEmpty,
            reason: receipt.receiptKey,
          );
        }
      });

      test('not in the CSV export either', () async {
        final export = await staff.call(
          'POST',
          '/api/book/export',
          json: const BookModel().query().toJson(),
        );
        expect(export.status, 200, reason: export.body);
        expect(export.body, contains('Comet in Moominland'));
        expect(leaksIn(export.body), isEmpty, reason: export.body);
      });
    });

    group('a client cannot write it', () {
      test('create, update and graph commit refuse the column', () async {
        final create = await staff.call(
          'POST',
          '/api/book',
          json: {
            'title': 'Smuggled',
            'isbn': 'smuggled-1',
            'format': 'ebook',
            'priceInCents': 100,
            'stock': 1,
            'authorId': catalog.tove.id,
            'supplierCostInCents': 1,
          },
        );
        expect(create.status, 422, reason: create.body);
        expect(
          await sp.Book.db.count(
            sessionBuilder.build(),
            where: (t) => t.isbn.equals('smuggled-1'),
          ),
          0,
        );

        final patch = await staff.call(
          'PATCH',
          '/api/book/${bookId()}',
          json: {'supplierCostInCents': 1},
        );
        expect(patch.status, 422, reason: patch.body);

        final commit = await staff.call(
          'POST',
          '/api/commits',
          json: updatePlan('leak-2', {
            'supplierCostInCents': const BeakIntValue(1),
          }).toJson(),
        );
        expect(
          commit.status == 200
              ? BeakSaveResult.fromJson(_json(commit)).complete
              : false,
          isFalse,
          reason: commit.body,
        );
        expect(await storedSupplierCost(), leakSupplierCostInCents);
      });
    });

    group('the tunnel only reaches the API', () {
      test(
        'every path that could steer the router elsewhere is a 404',
        () async {
          for (final path in [
            '/api/auth/login',
            '/api/book/../auth/login',
            '/api/%2e%2e/auth/login',
            '/api//book/query',
            '/api/book%2f..%2fauth',
            '/healthz',
            '/uploads/book/cover.png',
            '/',
          ]) {
            final reply = await staff.forged(
              'POST',
              path,
              json: const <String, Object?>{},
            );
            expect(reply.status, 404, reason: '$path -> ${reply.body}');
          }
        },
      );

      test('forged credential headers do not lift a gate-only user', () async {
        final gateOnly = tunnel(signedIn({BeakScopes.admin}));
        final reply = await gateOnly.forged(
          'GET',
          '/api/book/${bookId()}',
          headers: {
            'authorization': 'Bearer forged',
            'cookie': 'serverpod_auth=forged',
            'x-beak-roles': BookshopScopes.staff.name!,
            'x-forwarded-user': _staffId,
          },
        );
        expect(reply.status, 403, reason: reply.body);
      });
    });
  });
}
