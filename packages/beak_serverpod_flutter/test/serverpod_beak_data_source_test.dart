import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod_flutter/beak_serverpod_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serverpod_client/serverpod_client.dart';

void main() {
  test(
    'the data source tunnels through dispatch with no bearer token',
    () async {
      final sent = <BeakWireRequest>[];
      final source = serverpodBeakDataSource((request) async {
        sent.add(BeakWireRequest.decode(request));
        const page = BeakPage<BeakRecord>(
          items: [
            BeakRecord(
              values: {
                'id': BeakIntValue(1),
                'title': BeakStringValue('Moominsummer Madness'),
              },
            ),
          ],
          total: 1,
          page: 1,
          perPage: 25,
        );
        return BeakWireResponse(
          status: 200,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode(page.toJson((record) => record.toJson())),
        ).encode();
      });
      final page = await source.query(const BeakQuerySpec(table: 'book'));
      expect(page.total, 1);
      expect(page.items.single['title']?.raw, 'Moominsummer Madness');
      expect(sent.single.method, 'POST');
      expect(sent.single.path, '/api/book/query');
      expect(sent.single.headers.containsKey('authorization'), isFalse);
    },
  );

  test('a gate refusal reaches the panel as a typed Beak exception', () async {
    final source = serverpodBeakDataSource(
      (_) async => throw ServerpodClientForbidden(),
    );
    await expectLater(
      source.query(const BeakQuerySpec(table: 'book')),
      throwsA(isA<BeakAuthorizationException>()),
    );
  });
}
