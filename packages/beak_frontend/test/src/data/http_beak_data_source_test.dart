import 'dart:convert';
import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late List<http.Request> requests;
  late HttpBeakDataSource dataSource;

  Map<String, Object?> recordJson(Map<String, Object?> values) => {
    'values': values,
    'relations': const <String, Object?>{},
  };

  setUp(() {
    requests = [];
    dataSource = HttpBeakDataSource(
      BeakClient(
        baseUrl: 'http://api.test',
        httpClient: MockClient((request) async {
          requests.add(request);
          final Object? body = switch ((request.method, request.url.path)) {
            ('POST', '/api/notes/query') => {
              'items': [
                recordJson({'id': 'n1'}),
              ],
              'total': 1,
              'page': 1,
              'perPage': 25,
            },
            ('POST', '/api/notes/batch') => [
              recordJson({'id': 'n1'}),
            ],
            ('POST', '/api/notes/aggregate') => {'value': 7},
            ('POST', '/api/notes/avatar/upload') => {
              'key': 'notes/avatars/a.png',
              'url': 'https://cdn.test/a.png',
              'sizeInBytes': 3,
              'mimeType': 'image/png',
              'widthInPixels': null,
              'heightInPixels': null,
              'variants': <String, Object?>{},
            },
            ('DELETE', _) => null,
            (_, final String path) when path.contains('/relations/') => null,
            _ => recordJson({'id': 'n1'}),
          };
          return http.Response(
            body == null ? '' : jsonEncode(body),
            body == null ? 204 : 200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
  });

  test(
    'delegates the full BeakDataSource surface onto the REST client',
    () async {
      final page = await dataSource.query(const BeakQuerySpec(table: 'notes'));
      expect(page.total, 1);

      final record = await dataSource.getOne('notes', 'n1');
      expect(record?['id'], const BeakStringValue('n1'));

      await dataSource.create('notes', BeakRecord.fromRow(const {'id': 'n1'}));
      await dataSource.update(
        'notes',
        'n1',
        BeakRecord.fromRow(const {'title': 'Two'}),
      );
      await dataSource.delete('notes', 'n1', force: true);
      await dataSource.batchGet('notes', const ['n1']);
      await dataSource.attach('notes', 'n1', 'labels', const ['l1']);
      await dataSource.detach('notes', 'n1', 'labels', const ['l1']);
      final num total = await dataSource.aggregate(
        const BeakAggregateSpec.count(table: 'notes'),
      );
      expect(total, 7);
      final stored = await dataSource.upload(
        'notes',
        'avatar',
        BeakUpload(
          filename: 'a.png',
          mimeType: 'image/png',
          bytes: Uint8List(3),
        ),
      );
      expect(stored.key, 'notes/avatars/a.png');

      expect(
        [
          for (final request in requests)
            '${request.method} ${request.url.path}',
        ],
        [
          'POST /api/notes/query',
          'GET /api/notes/n1',
          'POST /api/notes',
          'PATCH /api/notes/n1',
          'DELETE /api/notes/n1',
          'POST /api/notes/batch',
          'POST /api/notes/n1/relations/labels/attach',
          'POST /api/notes/n1/relations/labels/detach',
          'POST /api/notes/aggregate',
          'POST /api/notes/avatar/upload',
        ],
      );
    },
  );

  test('a malformed aggregate response is a configuration error', () async {
    final broken = HttpBeakDataSource(
      BeakClient(
        baseUrl: 'http://api.test',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({'value': 'seven'}),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      ),
    );

    await expectLater(
      broken.aggregate(const BeakAggregateSpec.count(table: 'notes')),
      throwsA(isA<BeakConfigurationException>()),
    );
  });
}
