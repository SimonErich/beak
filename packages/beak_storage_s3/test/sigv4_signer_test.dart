import 'dart:convert';

import 'package:beak_storage_s3/src/sigv4_signer.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

/// SHA-256 of the empty payload, as S3 spells it in `x-amz-content-sha256`.
const String emptyPayloadSha256 =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

/// The credentials AWS publishes in the S3 Signature Version 4 examples.
const SigV4Signer s3ExampleSigner = SigV4Signer(
  accessKey: 'AKIAIOSFODNN7EXAMPLE',
  secretKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
  region: 'us-east-1',
);

/// The moment every S3 example in the AWS documentation is signed at.
final DateTime s3ExampleTime = DateTime.utc(2013, 5, 24);

String authorizationOf(Map<String, String> headers) =>
    headers['authorization'] ?? '';

void main() {
  group('SigV4Signer against the published AWS test vectors', () {
    // The header-based examples come from "Signature Calculations for the
    // Authorization Header" in the S3 API reference; the presigned one from
    // "Authenticating Requests: Using Query Parameters".
    group('S3 examples (AKIAIOSFODNN7EXAMPLE, examplebucket, 2013-05-24)', () {
      test('GET Object with a Range header', () {
        final Map<String, String> signed = s3ExampleSigner.signHeaders(
          method: 'GET',
          url: Uri.parse('https://examplebucket.s3.amazonaws.com/test.txt'),
          headers: {
            'host': 'examplebucket.s3.amazonaws.com',
            'range': 'bytes=0-9',
            'x-amz-content-sha256': emptyPayloadSha256,
          },
          payloadSha256: emptyPayloadSha256,
          timestamp: s3ExampleTime,
        );
        expect(
          authorizationOf(signed),
          'AWS4-HMAC-SHA256 '
          'Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request,'
          'SignedHeaders=host;range;x-amz-content-sha256;x-amz-date,'
          'Signature=f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41',
        );
        expect(signed['x-amz-date'], '20130524T000000Z');
      });

      test('PUT Object: a payload, a Date header, an unsafe key character', () {
        final String payloadSha256 = sha256
            .convert(utf8.encode('Welcome to Amazon S3.'))
            .toString();
        expect(
          payloadSha256,
          '44ce7dd67c959e0d3524ffac1771dfbba87d2b6b4b4e99e42034a8b803f8b072',
        );
        final Map<String, String> signed = s3ExampleSigner.signHeaders(
          method: 'PUT',
          url: Uri.parse(
            'https://examplebucket.s3.amazonaws.com/test\$file.text',
          ),
          headers: {
            'date': 'Fri, 24 May 2013 00:00:00 GMT',
            'host': 'examplebucket.s3.amazonaws.com',
            'x-amz-content-sha256': payloadSha256,
            'x-amz-storage-class': 'REDUCED_REDUNDANCY',
          },
          payloadSha256: payloadSha256,
          timestamp: s3ExampleTime,
        );
        expect(
          authorizationOf(signed),
          'AWS4-HMAC-SHA256 '
          'Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request,'
          'SignedHeaders=date;host;x-amz-content-sha256;x-amz-date;'
          'x-amz-storage-class,'
          'Signature=98ad721746da40c64f1a55b78f14c238d841ea1380cd77a1b5971af0ece108bd',
        );
      });

      test('GET Bucket Lifecycle: a query parameter without a value', () {
        final Map<String, String> signed = s3ExampleSigner.signHeaders(
          method: 'GET',
          url: Uri.parse('https://examplebucket.s3.amazonaws.com/?lifecycle'),
          headers: {
            'host': 'examplebucket.s3.amazonaws.com',
            'x-amz-content-sha256': emptyPayloadSha256,
          },
          payloadSha256: emptyPayloadSha256,
          timestamp: s3ExampleTime,
        );
        expect(
          authorizationOf(signed),
          endsWith(
            'Signature=fea454ca298b7da1c68078a5d1bdbfbbe0d65c699e0f91ac7a200a0136783543',
          ),
        );
      });

      test('GET Bucket (List Objects): query parameters are sorted', () {
        final Map<String, String> signed = s3ExampleSigner.signHeaders(
          method: 'GET',
          url: Uri.parse(
            'https://examplebucket.s3.amazonaws.com/?prefix=J&max-keys=2',
          ),
          headers: {
            'host': 'examplebucket.s3.amazonaws.com',
            'x-amz-content-sha256': emptyPayloadSha256,
          },
          payloadSha256: emptyPayloadSha256,
          timestamp: s3ExampleTime,
        );
        expect(
          authorizationOf(signed),
          endsWith(
            'Signature=34b48302e7b5fa45bde8084f4b7868a86f0a534bc59db6670ed5711ef69dc6f7',
          ),
        );
      });

      test('presigned GET URL valid for 86400 seconds', () {
        final Uri presigned = s3ExampleSigner.presignUrl(
          method: 'GET',
          url: Uri.parse('https://examplebucket.s3.amazonaws.com/test.txt'),
          expiresInSeconds: 86400,
          timestamp: s3ExampleTime,
        );
        expect(
          presigned.toString(),
          'https://examplebucket.s3.amazonaws.com/test.txt'
          '?X-Amz-Algorithm=AWS4-HMAC-SHA256'
          '&X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20130524%2Fus-east-1%2Fs3%2Faws4_request'
          '&X-Amz-Date=20130524T000000Z'
          '&X-Amz-Expires=86400'
          '&X-Amz-SignedHeaders=host'
          '&X-Amz-Signature=aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404',
        );
      });
    });

    test('the AWS SigV4 test suite: get-vanilla (a non-S3 service)', () {
      const SigV4Signer signer = SigV4Signer(
        accessKey: 'AKIDEXAMPLE',
        secretKey: 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY',
        region: 'us-east-1',
        service: 'service',
      );
      final Map<String, String> signed = signer.signHeaders(
        method: 'GET',
        url: Uri.parse('https://example.amazonaws.com/'),
        headers: {'host': 'example.amazonaws.com'},
        payloadSha256: emptyPayloadSha256,
        timestamp: DateTime.utc(2015, 8, 30, 12, 36),
      );
      // The suite's `.authz` file separates the parts with ", ", the S3
      // examples with ","; AWS accepts both and the signature is the same.
      expect(
        authorizationOf(signed).replaceAll(',', ', '),
        'AWS4-HMAC-SHA256 '
        'Credential=AKIDEXAMPLE/20150830/us-east-1/service/aws4_request, '
        'SignedHeaders=host;x-amz-date, '
        'Signature=5fa00fa31553b73ebf1942676e86291e8372ff2a2260956d9b8aae1d763fbf31',
      );
    });
  });

  group('SigV4Signer behavior', () {
    test('keeps the caller headers and adds the date and authorization', () {
      final Map<String, String> signed = s3ExampleSigner.signHeaders(
        method: 'GET',
        url: Uri.parse('https://examplebucket.s3.amazonaws.com/test.txt'),
        headers: {'host': 'examplebucket.s3.amazonaws.com', 'x-custom': 'a'},
        payloadSha256: emptyPayloadSha256,
        timestamp: s3ExampleTime,
      );
      expect(signed['host'], 'examplebucket.s3.amazonaws.com');
      expect(signed['x-custom'], 'a');
      expect(signed.keys, containsAll(['x-amz-date', 'authorization']));
    });

    test('lowercases header names and collapses their whitespace', () {
      final Map<String, String> spaced = s3ExampleSigner.signHeaders(
        method: 'GET',
        url: Uri.parse('https://examplebucket.s3.amazonaws.com/test.txt'),
        headers: {
          'Host': 'examplebucket.s3.amazonaws.com',
          'X-Custom': '  a   b ',
        },
        payloadSha256: emptyPayloadSha256,
        timestamp: s3ExampleTime,
      );
      final Map<String, String> tidy = s3ExampleSigner.signHeaders(
        method: 'GET',
        url: Uri.parse('https://examplebucket.s3.amazonaws.com/test.txt'),
        headers: {'host': 'examplebucket.s3.amazonaws.com', 'x-custom': 'a b'},
        payloadSha256: emptyPayloadSha256,
        timestamp: s3ExampleTime,
      );
      expect(authorizationOf(spaced), authorizationOf(tidy));
    });

    test('signs in UTC whatever the timestamp zone', () {
      final Map<String, String> signed = s3ExampleSigner.signHeaders(
        method: 'GET',
        url: Uri.parse('https://examplebucket.s3.amazonaws.com/test.txt'),
        headers: {'host': 'examplebucket.s3.amazonaws.com'},
        payloadSha256: emptyPayloadSha256,
        timestamp: DateTime.parse('2013-05-24T02:00:00+02:00'),
      );
      expect(signed['x-amz-date'], '20130524T000000Z');
    });

    test('encodes a key the way S3 canonicalizes it, once', () {
      final Map<String, String> literal = s3ExampleSigner.signHeaders(
        method: 'GET',
        url: Uri.parse('https://examplebucket.s3.amazonaws.com/a b/é+(1)!.png'),
        headers: {'host': 'examplebucket.s3.amazonaws.com'},
        payloadSha256: emptyPayloadSha256,
        timestamp: s3ExampleTime,
      );
      final Map<String, String> encoded = s3ExampleSigner.signHeaders(
        method: 'GET',
        url: Uri.parse(
          'https://examplebucket.s3.amazonaws.com/a%20b/%C3%A9%2B%281%29%21.png',
        ),
        headers: {'host': 'examplebucket.s3.amazonaws.com'},
        payloadSha256: emptyPayloadSha256,
        timestamp: s3ExampleTime,
      );
      expect(authorizationOf(literal), authorizationOf(encoded));
    });

    test('a presigned URL carries the port in the signed host', () {
      final Uri withPort = s3ExampleSigner.presignUrl(
        method: 'GET',
        url: Uri.parse('http://localhost:29000/bucket/key.png'),
        expiresInSeconds: 300,
        timestamp: s3ExampleTime,
      );
      final Uri withoutPort = s3ExampleSigner.presignUrl(
        method: 'GET',
        url: Uri.parse('http://localhost/bucket/key.png'),
        expiresInSeconds: 300,
        timestamp: s3ExampleTime,
      );
      expect(withPort.port, 29000);
      expect(
        withPort.queryParameters['X-Amz-Signature'],
        isNot(withoutPort.queryParameters['X-Amz-Signature']),
      );
    });

    test('a presigned URL keeps the query the caller already had', () {
      final Uri presigned = s3ExampleSigner.presignUrl(
        method: 'GET',
        url: Uri.parse(
          'https://examplebucket.s3.amazonaws.com/test.txt'
          '?response-content-type=text%2Fplain',
        ),
        expiresInSeconds: 60,
        timestamp: s3ExampleTime,
      );
      expect(presigned.queryParameters['response-content-type'], 'text/plain');
      expect(presigned.queryParameters['X-Amz-Expires'], '60');
    });

    test('rejects a presign lifetime outside 1 second to 7 days', () {
      for (final int seconds in [0, -1, 604801]) {
        expect(
          () => s3ExampleSigner.presignUrl(
            method: 'GET',
            url: Uri.parse('https://examplebucket.s3.amazonaws.com/test.txt'),
            expiresInSeconds: seconds,
            timestamp: s3ExampleTime,
          ),
          throwsA(isA<ArgumentError>()),
          reason: '$seconds seconds',
        );
      }
      expect(
        s3ExampleSigner
            .presignUrl(
              method: 'GET',
              url: Uri.parse('https://examplebucket.s3.amazonaws.com/t'),
              expiresInSeconds: 604800,
              timestamp: s3ExampleTime,
            )
            .queryParameters['X-Amz-Expires'],
        '604800',
      );
    });
  });
}
