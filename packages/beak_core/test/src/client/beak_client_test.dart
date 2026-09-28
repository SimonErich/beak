import 'dart:convert';
import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';

import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late List<http.BaseRequest> requests;
  late List<String> bodies;

  BeakClient client(
    Object? responseBody, {
    int statusCode = 200,
    String? token,
  }) {
    requests = [];
    bodies = [];
    return BeakClient(
      baseUrl: 'http://api.test/',
      tokenProvider: token == null ? null : () => token,
      httpClient: MockClient((request) async {
        requests.add(request);
        bodies.add(request.body);
        return http.Response(
          responseBody == null ? '' : jsonEncode(responseBody),
          statusCode,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }

  test('export overrides round trip and reject malformed metadata', () {
    const display = BeakExportFormat(
      BeakValueFormat.currency,
      minorUnits: true,
      scale: 3,
    );
    final restored = BeakExportFormat.fromJson(display.toJson());
    expect(restored.format, display.format);
    expect(restored.minorUnits, true);
    expect(restored.scale, 3);
    expect(BeakExportFormat.fromJson({'format': 'number'}).scale, 2);
    for (final invalid in <Map<String, Object?>>[
      {},
      {'format': 'unknown'},
      {'format': 'currency', 'minorUnits': 'yes'},
      {'format': 'currency', 'scale': '2'},
      {'format': 'currency', 'scale': -1},
      {'format': 'currency', 'scale': 13},
    ]) {
      expect(() => BeakExportFormat.fromJson(invalid), throwsFormatException);
    }
  });

  Map<String, Object?> recordJson(Map<String, Object?> values) => {
    'values': values,
    'relations': const <String, Object?>{},
  };

  group('request shapes', () {
    test('summary transports typed population and bounded results', () async {
      final response = BeakSummaryResult(
        rows: [
          BeakSummaryRow(
            group: const BeakStringValue('paid'),
            values: {'orders': 412},
          ),
        ],
        truncated: true,
      );
      final api = client(response.toJson());
      final spec = BeakSummarySpec.forKeys(
        table: 'orders',
        groupByKey: 'status',
        measures: const [BeakSummaryMeasure.count('orders')],
      );
      final result = await api.summary(spec);
      expect(requests.single.url.path, '/api/orders/summary');
      expect(jsonDecode(bodies.single), spec.toJson());
      expect(result.toJson(), response.toJson());
    });
    test(
      'capabilities uses encoded identity and authenticated transport',
      () async {
        final api = client({
          'readableFields': ['name'],
          'writableFields': <String>[],
        }, token: 'session');
        final access = await api.capabilities('products', id: 'id / one');
        expect(access.canRead('name'), isTrue);
        expect(access.canWrite('name'), isFalse);
        expect(requests.single.url.queryParameters['id'], 'id / one');
        expect(requests.single.headers['authorization'], 'Bearer session');
        api.close();
      },
    );
    test(
      'commit submits a frozen graph and recovers its durable receipt',
      () async {
        final receipt = BeakSaveResult(
          saveId: 'save / 1',
          mode: BeakSaveMode.atomic,
          outcomes: [],
        );
        final api = client(receipt.toJson());
        final plan = BeakSavePlan(
          saveId: receipt.saveId,
          root: const BeakRecordRef.existing('notes', 'n1'),
          operations: [],
        );
        expect((await api.commit(plan)).toJson(), receipt.toJson());
        expect(requests.last.method, 'POST');
        expect(requests.last.url.path, '/api/commits');
        expect(jsonDecode(bodies.last), plan.toJson());
        expect(
          (await api.recoverCommit(receipt.saveId)).toJson(),
          receipt.toJson(),
        );
        expect(requests.last.method, 'GET');
        expect(requests.last.url.pathSegments.last, receipt.saveId);
        api.close();
      },
    );
    test(
      'validation submits candidate state and decodes structured errors',
      () async {
        final api = client({
          'fieldErrors': {
            'title': ['Already used.'],
          },
        });
        final candidate = BeakValidationRequest(
          table: 'notes',
          record: BeakRecord.fromRow({'title': 'Same'}),
          recordId: 'existing',
        );
        expect((await api.validateRecord(candidate)).fieldErrors, {
          'title': ['Already used.'],
        });
        expect(requests.single.method, 'POST');
        expect(requests.single.url.path, '/api/notes/validate');
        expect(jsonDecode(bodies.single), candidate.toJson());
        api.close();
      },
    );
    test('query posts the spec to /api/{table}/query', () async {
      final page = await client({
        'items': [
          recordJson({'id': 'n1', 'title': 'One'}),
        ],
        'total': 1,
        'page': 1,
        'perPage': 25,
      }).query('notes', const BeakQuerySpec(table: 'notes'));

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.toString(), 'http://api.test/api/notes/query');
      expect(
        jsonDecode(bodies.single),
        const BeakQuerySpec(table: 'notes').toJson(),
      );
      expect(page.total, 1);
      expect(page.items.single['title'], const BeakStringValue('One'));
    });

    test('getOne gets /api/{table}/{id}', () async {
      final record = await client(
        recordJson({'id': 'n1'}),
      ).getOne('notes', 'n1');
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/api/notes/n1');
      expect(record?['id'], const BeakStringValue('n1'));
    });

    test('getOne returns null on 404', () async {
      final record = await client(const {
        'code': 'not_found',
        'message': 'missing',
      }, statusCode: 404).getOne('notes', 'ghost');
      expect(record, isNull);
    });

    test('create posts flat wire values', () async {
      final created =
          await client(
            recordJson({'id': 'n1', 'title': 'One'}),
            statusCode: 201,
          ).create(
            'notes',
            BeakRecord.fromRow({
              'title': 'One',
              'created_at': DateTime.utc(2026, 7, 3),
            }),
          );
      expect(requests.single.url.path, '/api/notes');
      expect(jsonDecode(bodies.single), {
        'title': 'One',
        'created_at': {
          'type': 'dateTime',
          'value': DateTime.utc(2026, 7, 3).toIso8601String(),
        },
      });
      expect(created['id'], const BeakStringValue('n1'));
    });

    test('update patches flat wire values', () async {
      await client(
        recordJson({'id': 'n1', 'rating': 5}),
      ).update('notes', 'n1', BeakRecord.fromRow(const {'rating': 5}));
      expect(requests.single.method, 'PATCH');
      expect(requests.single.url.path, '/api/notes/n1');
      expect(jsonDecode(bodies.single), {'rating': 5});
    });

    test('delete hits /api/{table}/{id} and forwards force', () async {
      await client(null, statusCode: 204).delete('notes', 'n1', force: true);
      expect(requests.single.method, 'DELETE');
      expect(requests.single.url.path, '/api/notes/n1');
      expect(requests.single.url.queryParameters, {'force': 'true'});
    });

    test(
      'restore posts /api/{table}/{id}/restore and parses the record',
      () async {
        final record = await client(
          recordJson({'id': 'n1'}),
        ).restore('notes', 'n1');

        expect(requests.single.method, 'POST');
        expect(requests.single.url.path, '/api/notes/n1/restore');
        expect(record['id']?.raw, 'n1');
      },
    );

    test('batchGet posts ids and parses the list', () async {
      final records = await client([
        recordJson({'id': 'n1'}),
        recordJson({'id': 'n2'}),
      ]).batchGet('notes', const ['n1', 'n2']);
      expect(requests.single.url.path, '/api/notes/batch');
      expect(jsonDecode(bodies.single), {
        'ids': ['n1', 'n2'],
      });
      expect(records, hasLength(2));
    });

    test('attach and detach post relation ids', () async {
      final attachClient = client(null, statusCode: 204);
      await attachClient.attach('notes', 'n1', 'labels', const ['l1']);
      expect(requests.single.url.path, '/api/notes/n1/relations/labels/attach');

      final detachClient = client(null, statusCode: 204);
      await detachClient.detach('notes', 'n1', 'labels', const ['l1']);
      expect(requests.single.url.path, '/api/notes/n1/relations/labels/detach');
    });

    test(
      'discard removes variants and main key with authenticated idempotent requests',
      () async {
        final api = client(null, statusCode: 404, token: 'token');
        final stored = BeakStoredFile(
          key: 'photos/main.png',
          url: Uri.parse('https://cdn/main.png'),
          sizeInBytes: 2,
          mimeType: 'image/png',
          variants: {
            'thumb': BeakStoredFileVariant(
              key: 'photos/thumb.png',
              url: Uri.parse('https://cdn/thumb.png'),
            ),
          },
        );
        await api.discardUpload('notes', 'avatar', stored);
        expect(requests.map((r) => r.method), ['DELETE', 'DELETE']);
        expect(bodies.map(jsonDecode), [
          {'key': 'photos/thumb.png'},
          {'key': 'photos/main.png'},
        ]);
        expect(
          requests.every((r) => r.headers['authorization'] == 'Bearer token'),
          true,
        );
        api.close();
      },
    );
    test(
      'upload URL lookup preserves storage key as encoded query data',
      () async {
        final api = client({'url': 'https://cdn.test/signed?token=123'});
        expect(
          await api.uploadUrl('notes', 'avatar', 'photos/a b.png'),
          Uri.parse('https://cdn.test/signed?token=123'),
        );
        expect(requests.single.url.queryParameters['key'], 'photos/a b.png');
        api.close();
      },
    );

    test('upload posts the file as multipart form data', () async {
      final storedJson = BeakStoredFile(
        key: 'avatars/a.png',
        url: Uri.parse('memory:///avatars/a.png'),
        sizeInBytes: 3,
        mimeType: 'image/png',
      ).toJson();

      final stored = await client(storedJson, statusCode: 201).upload(
        'notes',
        'avatar',
        BeakUpload(
          filename: 'a.png',
          mimeType: 'image/png',
          bytes: Uint8List.fromList(const [1, 2, 3]),
        ),
      );

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/notes/avatar/upload');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data'),
      );
      expect(bodies.single, contains('filename="a.png"'));
      expect(stored.key, 'avatars/a.png');
    });

    test('export posts the spec and returns the CSV body', () async {
      requests = [];
      final exporting = BeakClient(
        baseUrl: 'http://api.test',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            'Id,Title\r\nn1,One\r\n',
            200,
            headers: {'content-type': 'text/csv; charset=utf-8'},
          );
        }),
      );

      final String csv = await exporting.export(
        'notes',
        const BeakQuerySpec(table: 'notes'),
        columns: const ['title'],
        formats: const {'title': BeakExportFormat(BeakValueFormat.text)},
      );

      expect(requests.single.url.path, '/api/notes/export');
      expect(
        (jsonDecode((requests.single as http.Request).body) as Map)['columns'],
        ['title'],
      );
      expect(
        (jsonDecode((requests.single as http.Request).body) as Map)['formats'],
        {'title': const BeakExportFormat(BeakValueFormat.text).toJson()},
      );
      expect(csv, 'Id,Title\r\nn1,One\r\n');
    });

    test(
      'export forwards shared portable policy and explicit raw mode',
      () async {
        final exporting = client(null);
        const policy = BeakFormatPolicy(
          locale: 'de_AT',
          currency: 'EUR',
          timeZoneOffsetMinutes: 60,
        );
        await exporting.export(
          'notes',
          const BeakQuerySpec(table: 'notes'),
          formatting: policy,
        );
        final Object? body = jsonDecode(bodies.single);
        expect(body, containsPair('formatting', policy.toJson()));
        await exporting.export(
          'notes',
          const BeakQuerySpec(table: 'notes'),
          raw: true,
        );
        final Object? rawBody = jsonDecode(bodies.last);
        expect(rawBody, containsPair('raw', true));
        expect(
          () => exporting.export(
            'notes',
            const BeakQuerySpec(table: 'notes'),
            raw: true,
            formatting: policy,
          ),
          throwsA(isA<BeakConfigurationException>()),
        );
        expect(bodies, hasLength(2));
      },
    );

    test('search flattens grouped hits in order', () async {
      final hits = await client({
        'results': {
          'notes': [
            const BeakSearchHit(
              table: 'notes',
              id: 'n1',
              displayLabel: 'One',
              matchedColumnKey: 'title',
            ).toJson(),
          ],
          'labels': [
            const BeakSearchHit(
              table: 'labels',
              id: 'l1',
              displayLabel: 'hot',
              matchedColumnKey: 'name',
            ).toJson(),
          ],
        },
      }).search('o');
      expect(requests.single.url.path, '/api/search');
      expect(requests.single.url.queryParameters, {'q': 'o'});
      expect(hits, hasLength(2));
      expect(hits.first.table, 'notes');
      expect(hits.last.table, 'labels');
    });

    test('a token provider attaches the Bearer header everywhere', () async {
      await client(
        recordJson({'id': 'n1'}),
        token: 'session-token',
      ).getOne('notes', 'n1');
      expect(requests.single.headers['authorization'], 'Bearer session-token');
    });
  });

  group('error mapping', () {
    Future<void> expectThrows<T>(int statusCode, Map<String, Object?> body) {
      return expectLater(
        client(body, statusCode: statusCode).getOne('notes', 'n1'),
        throwsA(isA<T>()),
      );
    }

    test('422 maps to a validation exception with field errors', () async {
      Object? caught;
      try {
        await client(const {
          'code': 'validation',
          'message': 'Validation failed.',
          'fieldErrors': {
            'title': ['This field is required.'],
          },
        }, statusCode: 422).create('notes', BeakRecord.fromRow(const {}));
      } on BeakValidationException catch (exception) {
        caught = exception;
        expect(exception.fieldErrors, {
          'title': ['This field is required.'],
        });
      }
      expect(caught, isNotNull);
    });

    test('statuses map onto the typed exception family', () async {
      await expectThrows<BeakAuthenticationException>(401, const {
        'code': 'authentication',
        'message': 'Sign in.',
      });
      await expectThrows<BeakAuthorizationException>(403, const {
        'code': 'authorization',
        'message': 'Forbidden.',
      });
      await expectThrows<BeakConflictException>(409, const {
        'code': 'conflict',
        'message': 'Conflict.',
      });
      await expectThrows<BeakStorageException>(500, const {
        'code': 'storage',
        'message': 'Disk on fire.',
      });
      await expectThrows<BeakConfigurationException>(500, const {
        'code': 'internal',
        'message': 'Server error.',
      });
    });

    test('delete surfaces 404 as not-found', () {
      expect(
        () => client(const {
          'code': 'not_found',
          'message': 'missing',
        }, statusCode: 404).delete('notes', 'ghost'),
        throwsA(isA<BeakNotFoundException>()),
      );
    });

    test('an unparsable error body still maps by status', () {
      expect(
        () => client(null, statusCode: 500).delete('notes', 'n1'),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('a non-object JSON error body degrades to configuration', () {
      expect(
        () => client(const [1, 2], statusCode: 404).delete('notes', 'n1'),
        throwsA(
          isA<BeakConfigurationException>().having(
            (exception) => exception.message,
            'message',
            'HTTP 404.',
          ),
        ),
      );
    });
  });

  group('response shape guards', () {
    test('a real HTTP client constructs by default and closes cleanly', () {
      BeakClient(baseUrl: 'http://localhost:1').close();
    });

    test('aggregate returns the numeric value', () async {
      expect(
        await client(const {
          'value': 7,
        }).aggregate('notes', const BeakAggregateSpec.count(table: 'notes')),
        7,
      );
    });

    test('a non-numeric aggregate value is a configuration error', () {
      expect(
        () => client(const {
          'value': 'seven',
        }).aggregate('notes', const BeakAggregateSpec.count(table: 'notes')),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('a search response without a results object is rejected', () {
      expect(
        () => client(const {'results': 3}).search('x'),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => client(const <String, Object?>{}).search('x'),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('search groups that are not lists are rejected', () {
      expect(
        () => client(const {
          'results': {'notes': 'nope'},
        }).search('x'),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('a non-array batch response is rejected', () {
      expect(
        () => client(const {'items': 1}).batchGet('notes', const ['n1']),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('non-object records in responses are rejected', () {
      expect(
        () => client(const [1, 2]).batchGet('notes', const ['n1']),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('sessions', () {
    test('login returns the session and logout ends it', () async {
      final session = await client({
        'token': 'tok-1',
        'principal': {
          'id': 'u1',
          'roles': ['staff', 'admin'],
        },
      }).login(username: 'ada@example.com', password: 'espresso');

      expect(session.token, 'tok-1');
      expect(session.principalId, 'u1');
      expect(session.hasRole('staff'), isTrue);
      expect(session.hasRole('owner'), isFalse);
      expect(session.toString(), contains('u1'));
      expect(requests.single.url.path, '/api/auth/login');

      final target = client(null, statusCode: 204);
      await target.logout('tok-1');
      expect(requests.single.headers['authorization'], 'Bearer tok-1');
    });

    test('a session without roles is still a session', () {
      final session = BeakSession.fromJson(const {
        'token': 'tok',
        'principal': {'id': 'u2'},
      });
      expect(session.roles, isEmpty);
    });

    test('malformed principal roles are a configuration error', () {
      expect(
        () => BeakSession.fromJson(const {
          'token': 'tok',
          'principal': {'id': 'u3', 'roles': 'staff'},
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('baseUrl is readable and has no trailing slash', () {
      expect(client(null).baseUrl, 'http://api.test');
    });
  });

  test('a conditional update sends the timestamp it read', () async {
    final target = client(recordJson(const {'id': 'p1'}));
    await target.update(
      'products',
      'p1',
      BeakRecord.fromRow(const {'name': 'New'}),
      ifUnmodifiedSince: DateTime.utc(2026, 7, 27, 12),
    );

    expect(
      requests.single.headers['if-unmodified-since'],
      '2026-07-27T12:00:00.000Z',
    );
  });
}
