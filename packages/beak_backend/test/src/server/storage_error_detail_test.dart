import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

/// The raw text an S3 driver puts in its exception: it names the endpoint.
const String _driverDetail =
    'S3 put failed for "photos/a.png": ClientException: Connection refused, '
    'address = minio.internal.example, port = 9000';

Handler _throwing(BeakException exception) =>
    (Request request) => throw exception;

void main() {
  group('a storage failure', () {
    test('reaches the caller as a generic 500', () async {
      final handler = const Pipeline()
          .addMiddleware(beakErrorMappingMiddleware())
          .addHandler(_throwing(const BeakStorageException(_driverDetail)));

      final response = await handler(
        Request('POST', Uri.parse('http://localhost/api/x/y/upload')),
      );
      final String body = await response.readAsString();

      expect(response.statusCode, 500);
      expect(body, isNot(contains('minio.internal.example')));
      expect(body, isNot(contains('Connection refused')));
      expect(jsonDecode(body), {
        'code': 'storage',
        'message': 'File storage failed.',
      });
    });

    test('is reported with its detail to the project listener', () async {
      final heard = <Object>[];
      final handler = const Pipeline()
          .addMiddleware(
            beakErrorMappingMiddleware(
              onUnexpectedError: (error, stackTrace) => heard.add(error),
            ),
          )
          .addHandler(_throwing(const BeakStorageException(_driverDetail)));

      await handler(
        Request('POST', Uri.parse('http://localhost/api/x/y/upload')),
      );

      expect(heard, hasLength(1));
      expect(
        heard.single,
        isA<BeakStorageException>().having(
          (error) => error.message,
          'message',
          contains('minio.internal.example'),
        ),
      );
    });

    test('is not reported when it was never a 500', () async {
      final heard = <Object>[];
      final handler = const Pipeline()
          .addMiddleware(
            beakErrorMappingMiddleware(
              onUnexpectedError: (error, stackTrace) => heard.add(error),
            ),
          )
          .addHandler(_throwing(const BeakNotFoundException('No such row.')));

      final response = await handler(
        Request('GET', Uri.parse('http://localhost/api/x/1')),
      );

      expect(response.statusCode, 404);
      expect(heard, isEmpty);
    });
  });
}
