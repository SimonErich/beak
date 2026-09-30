import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

Request _get(String path, {Map<String, String> headers = const {}}) =>
    Request('GET', Uri.parse('http://localhost/$path'), headers: headers);

Map<String, Object?> _bodyJson(String body) => switch (jsonDecode(body)) {
  final Map<String, Object?> map => map,
  final Object? other => throw StateError('expected a JSON object, got $other'),
};

void main() {
  group('request log middleware', () {
    test(
      'attaches a request id, echoes it as a header and logs the request',
      () async {
        final entries = <BeakRequestLogEntry>[];
        final handler = const Pipeline()
            .addMiddleware(
              beakRequestLogMiddleware(
                onRequest: entries.add,
                requestIdFactory: () => 'fixed-id',
              ),
            )
            .addHandler(
              (request) => Response.ok('ok ${beakRequestId(request) ?? ''}'),
            );

        final response = await handler(_get('products'));

        expect(response.headers['x-request-id'], 'fixed-id');
        expect(await response.readAsString(), 'ok fixed-id');
        expect(entries, hasLength(1));
        final entry = entries.single;
        expect(entry.requestId, 'fixed-id');
        expect(entry.method, 'GET');
        expect(entry.path, 'products');
        expect(entry.statusCode, 200);
        expect(entry.duration, greaterThanOrEqualTo(Duration.zero));
      },
    );

    test('serialises to one line of JSON per request', () async {
      // A log aggregator indexes fields, not prose: "every 500 on
      // /api/orders in the last hour" should be a query, not a regex.
      final sink = StringBuffer();
      final handler = const Pipeline()
          .addMiddleware(
            beakRequestLogMiddleware(
              onRequest: beakJsonRequestLogger(sink: sink),
              requestIdFactory: () => 'fixed-id',
            ),
          )
          .addHandler((request) => Response(201));

      await handler(_get('products'));

      final List<String> lines = const LineSplitter().convert(sink.toString());
      expect(lines, hasLength(1));
      final Object? decoded = jsonDecode(lines.single);
      expect(decoded, isA<Map<String, Object?>>());
      if (decoded case final Map<String, Object?> entry) {
        expect(entry['requestId'], 'fixed-id');
        expect(entry['method'], 'GET');
        expect(entry['path'], '/products');
        expect(entry['statusCode'], 201);
        expect(entry['durationMs'], isA<int>());
      }
    });

    test('reuses an incoming x-request-id header', () async {
      final entries = <BeakRequestLogEntry>[];
      final handler = const Pipeline()
          .addMiddleware(beakRequestLogMiddleware(onRequest: entries.add))
          .addHandler((request) => Response.ok('ok'));

      final response = await handler(
        _get('products', headers: {'x-request-id': 'from-client'}),
      );

      expect(response.headers['x-request-id'], 'from-client');
      expect(entries.single.requestId, 'from-client');
    });

    test(
      'replaces an incoming x-request-id that is not a plain token',
      () async {
        // The id is echoed as a response header and printed in log lines, so a
        // client must not choose bytes a header cannot carry, or a value long
        // enough to fill the log.
        for (final hostile in [
          'caf\u00e9',
          'two words',
          'a;b',
          '',
          'x' * 129,
        ]) {
          final entries = <BeakRequestLogEntry>[];
          final handler = const Pipeline()
              .addMiddleware(
                beakRequestLogMiddleware(
                  onRequest: entries.add,
                  requestIdFactory: () => 'minted',
                ),
              )
              .addHandler((request) => Response.ok('ok'));

          final response = await handler(
            _get('products', headers: {'x-request-id': hostile}),
          );

          expect(response.headers['x-request-id'], 'minted', reason: hostile);
          expect(entries.single.requestId, 'minted', reason: hostile);
        }
      },
    );

    test('keeps an incoming id made of token characters', () async {
      final handler = const Pipeline()
          .addMiddleware(
            beakRequestLogMiddleware(
              onRequest: (_) {},
              requestIdFactory: () => 'minted',
            ),
          )
          .addHandler((request) => Response.ok('ok'));

      for (final id in ['a-b_c.d:e/f', 'X' * 128, '123e4567-e89b-12d3']) {
        final response = await handler(
          _get('products', headers: {'x-request-id': id}),
        );
        expect(response.headers['x-request-id'], id);
      }
    });

    test('generates unique ids by default', () async {
      final entries = <BeakRequestLogEntry>[];
      final handler = const Pipeline()
          .addMiddleware(beakRequestLogMiddleware(onRequest: entries.add))
          .addHandler((request) => Response.ok('ok'));

      await handler(_get('a'));
      await handler(_get('b'));

      expect(entries, hasLength(2));
      expect(entries[0].requestId, isNotEmpty);
      expect(entries[0].requestId, isNot(entries[1].requestId));
    });
  });

  group('cors middleware', () {
    test('adds CORS headers to normal responses', () async {
      final handler = const Pipeline()
          .addMiddleware(beakCorsMiddleware())
          .addHandler((request) => Response.ok('ok'));

      final response = await handler(_get('products'));

      expect(response.headers['access-control-allow-origin'], '*');
    });

    test(
      'short-circuits OPTIONS preflight without hitting the handler',
      () async {
        var handlerCalls = 0;
        final handler = const Pipeline()
            .addMiddleware(beakCorsMiddleware())
            .addHandler((request) {
              handlerCalls += 1;
              return Response.ok('ok');
            });

        final response = await handler(
          Request('OPTIONS', Uri.parse('http://localhost/products')),
        );

        expect(response.statusCode, 204);
        expect(response.headers['access-control-allow-origin'], '*');
        expect(response.headers['access-control-allow-methods'], isNotEmpty);
        expect(response.headers['access-control-allow-headers'], isNotEmpty);
        expect(handlerCalls, 0);
      },
    );

    test('a preflight admits every header the Beak client sends', () async {
      // A browser refuses the real request when a header it carries is not
      // listed here. `if-unmodified-since` is the optimistic-lock header an
      // edit sends, so leaving it out breaks every save from another origin.
      final handler = const Pipeline()
          .addMiddleware(beakCorsMiddleware())
          .addHandler((request) => Response.ok('ok'));

      final response = await handler(
        Request(
          'OPTIONS',
          Uri.parse('http://localhost/api/notes/n1'),
          headers: const {
            'access-control-request-method': 'PUT',
            'access-control-request-headers':
                'authorization, content-type, if-unmodified-since',
          },
        ),
      );

      final allowed = {
        for (final header
            in response.headers['access-control-allow-headers']!.split(','))
          header.trim(),
      };
      expect(
        allowed,
        containsAll([
          'authorization',
          'content-type',
          'if-unmodified-since',
          'x-request-id',
        ]),
      );
    });

    test(
      'a preflight lists the methods the routes use, and no others',
      () async {
        final handler = const Pipeline()
            .addMiddleware(beakCorsMiddleware())
            .addHandler((request) => Response.ok('ok'));

        final response = await handler(
          Request('OPTIONS', Uri.parse('http://localhost/api/notes/n1')),
        );

        final allowed = {
          for (final method
              in response.headers['access-control-allow-methods']!.split(','))
            method.trim(),
        };
        expect(allowed, {'GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'});
      },
    );

    test('honors a configured origin', () async {
      final handler = const Pipeline()
          .addMiddleware(
            beakCorsMiddleware(allowedOrigin: 'https://admin.example'),
          )
          .addHandler((request) => Response.ok('ok'));

      final response = await handler(_get('products'));

      expect(
        response.headers['access-control-allow-origin'],
        'https://admin.example',
      );
    });
  });

  group('json middleware', () {
    test('defaults the response content type to application/json', () async {
      final handler = const Pipeline()
          .addMiddleware(beakJsonMiddleware())
          .addHandler((request) => Response.ok('{"ok":true}'));

      final response = await handler(_get('products'));

      expect(response.headers['content-type'], contains('application/json'));
    });

    test('keeps an explicit content type untouched', () async {
      final handler = const Pipeline()
          .addMiddleware(beakJsonMiddleware())
          .addHandler(
            (request) =>
                Response.ok('a,b', headers: {'content-type': 'text/csv'}),
          );

      final response = await handler(_get('export'));

      expect(response.headers['content-type'], 'text/csv');
    });
  });

  group('readJsonObject', () {
    test('decodes a JSON object body', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/products'),
        body: '{"name":"Laser Pointer"}',
      );
      expect(await readJsonObject(request), {'name': 'Laser Pointer'});
    });

    test('rejects malformed JSON with a validation failure', () {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/products'),
        body: '{oops',
      );
      expect(
        () => readJsonObject(request),
        throwsA(isA<BeakValidationException>()),
      );
    });

    test('rejects a non-object JSON body with a validation failure', () {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/products'),
        body: '[1,2,3]',
      );
      expect(
        () => readJsonObject(request),
        throwsA(isA<BeakValidationException>()),
      );
    });

    test('rejects a body that is not UTF-8 with a validation failure', () {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/products'),
        body: const [0x7b, 0xff, 0xfe, 0x7d],
      );
      expect(
        () => readJsonObject(request),
        throwsA(isA<BeakValidationException>()),
      );
    });

    test('accepts a body that fills the limit exactly', () async {
      const body = '{"name":"abcdef"}';
      final request = Request(
        'POST',
        Uri.parse('http://localhost/products'),
        body: body,
      );
      expect(await readJsonObject(request, maxBodyInBytes: body.length), {
        'name': 'abcdef',
      });
    });

    test('refuses a body whose declared length is over the limit', () {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/products'),
        body: '{"name":"abcdef"}',
      );
      expect(
        () => readJsonObject(request, maxBodyInBytes: 8),
        throwsA(isA<BeakPayloadTooLargeException>()),
      );
    });

    test('stops reading a stream that outgrows the limit', () async {
      var chunksRead = 0;
      Stream<List<int>> endless() async* {
        while (true) {
          chunksRead += 1;
          yield List<int>.filled(1024, 0x20);
        }
      }

      final request = Request(
        'POST',
        Uri.parse('http://localhost/products'),
        body: endless(),
      );
      await expectLater(
        readJsonObject(request, maxBodyInBytes: 4096),
        throwsA(isA<BeakPayloadTooLargeException>()),
      );
      expect(chunksRead, lessThan(16));
    });

    test('the default limit is 16 MiB', () {
      expect(beakMaxJsonBodyInBytes, 16 * 1024 * 1024);
    });
  });

  group('error mapping middleware', () {
    Handler throwing(Object error) => const Pipeline()
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler((request) => throw error);

    test('maps validation failures to 422 with field errors', () async {
      final response = await throwing(
        const BeakValidationException(
          'Validation failed.',
          fieldErrors: {
            'name': ['Name is required.'],
          },
        ),
      )(_get('products'));

      expect(response.statusCode, 422);
      final body = _bodyJson(await response.readAsString());
      expect(body['code'], 'validation');
      expect(body['message'], 'Validation failed.');
      expect(body['fieldErrors'], {
        'name': ['Name is required.'],
      });
      expect(response.headers['content-type'], contains('application/json'));
    });

    test('maps every remaining Beak failure to its status', () async {
      const cases = <(BeakException, int)>[
        (BeakNotFoundException('missing'), 404),
        (BeakAuthorizationException('forbidden'), 403),
        (BeakConflictException('duplicate'), 409),
        (BeakConfigurationException('broken setup'), 500),
        (BeakPayloadTooLargeException('too big'), 413),
        (BeakTransportException('bad gateway'), 502),
      ];
      for (final (exception, expectedStatus) in cases) {
        final response = await throwing(exception)(_get('products'));
        expect(response.statusCode, expectedStatus, reason: exception.code);
        final body = _bodyJson(await response.readAsString());
        expect(body['code'], exception.code, reason: exception.code);
        expect(body['message'], exception.message, reason: exception.code);
        expect(body.containsKey('fieldErrors'), isFalse);
      }
    });

    test('answers a typed internal failure with the generic message and '
        'reports its detail', () async {
      final reported = <Object>[];
      final handler = const Pipeline()
          .addMiddleware(
            beakErrorMappingMiddleware(
              onUnexpectedError: (error, stackTrace) => reported.add(error),
            ),
          )
          .addHandler(
            (request) => throw const BeakInternalException(
              'The updated record could not be read from db-7.internal.',
            ),
          );

      final response = await handler(_get('products'));

      expect(response.statusCode, 500);
      final body = _bodyJson(await response.readAsString());
      expect(body['code'], 'internal');
      expect(body['message'], 'Internal server error.');
      expect(reported.single, isA<BeakInternalException>());
    });

    test('includes the request id in error bodies when present', () async {
      final handler = const Pipeline()
          .addMiddleware(
            beakRequestLogMiddleware(
              onRequest: (entry) {},
              requestIdFactory: () => 'err-id',
            ),
          )
          .addMiddleware(beakErrorMappingMiddleware())
          .addHandler((request) => throw const BeakNotFoundException('nope'));

      final response = await handler(_get('products'));

      final body = _bodyJson(await response.readAsString());
      expect(body['requestId'], 'err-id');
    });

    test('maps unexpected errors to an opaque 500 and reports them', () async {
      final reported = <Object>[];
      final handler = const Pipeline()
          .addMiddleware(
            beakErrorMappingMiddleware(
              onUnexpectedError: (error, stackTrace) => reported.add(error),
            ),
          )
          .addHandler((request) => throw StateError('secret internals'));

      final response = await handler(_get('products'));

      expect(response.statusCode, 500);
      final body = _bodyJson(await response.readAsString());
      expect(body['code'], 'internal');
      expect(body['message'], isNot(contains('secret')));
      expect(reported.single, isA<StateError>());
    });
  });

  group('auth middleware', () {
    test('passes through without a guard', () async {
      final handler = const Pipeline()
          .addMiddleware(beakAuthMiddleware())
          .addHandler((request) => Response.ok('ok'));

      final response = await handler(_get('products'));

      expect(response.statusCode, 200);
    });

    test('stores the resolved principal in the request context', () async {
      final handler = const Pipeline()
          .addMiddleware(
            beakAuthMiddleware(
              guard: const _FixedGuard(BeakPrincipal(id: 'u1')),
            ),
          )
          .addHandler(
            (request) => Response.ok(beakPrincipal(request)?.id ?? 'none'),
          );

      final response = await handler(_get('products'));

      expect(await response.readAsString(), 'u1');
    });

    test('leaves guardless anonymous requests without a principal', () async {
      final handler = const Pipeline()
          .addMiddleware(beakAuthMiddleware(guard: const _FixedGuard(null)))
          .addHandler(
            (request) => Response.ok(beakPrincipal(request)?.id ?? 'none'),
          );

      final response = await handler(_get('products'));

      expect(await response.readAsString(), 'none');
    });

    test('maps a guard denial through the error middleware', () async {
      final handler = const Pipeline()
          .addMiddleware(beakErrorMappingMiddleware())
          .addMiddleware(beakAuthMiddleware(guard: const _ThrowingGuard()))
          .addHandler((request) => Response.ok('ok'));

      final response = await handler(_get('products'));

      expect(response.statusCode, 401);
      final body = _bodyJson(await response.readAsString());
      expect(body['code'], 'authentication');
    });
  });
}

/// A guard resolving every request to a fixed principal (or anonymous).
final class _FixedGuard implements BeakAuthGuard {
  const _FixedGuard(this.principal);

  final BeakPrincipal? principal;

  @override
  Future<BeakPrincipal?> authenticate(Request request) async => principal;
}

/// A guard rejecting every request as unauthenticated.
final class _ThrowingGuard implements BeakAuthGuard {
  const _ThrowingGuard();

  @override
  Future<BeakPrincipal?> authenticate(Request request) async =>
      throw const BeakAuthenticationException('no way');
}
