import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';
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
        (BeakStorageException('disk on fire'), 500),
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
