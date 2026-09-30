import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web and contact destinations retain their encoded URI', () async {
    final launched = <Uri>[];
    for (final value in [
      'https://example.com/order?id=123',
      'mailto:orders@example.com?subject=Order%20123',
      'tel:+43123456',
      'sms:+43123456',
    ]) {
      final uri = Uri.parse(value);
      await launchBeakUri(
        uri,
        launcher: (destination) async {
          launched.add(destination);
          return true;
        },
      );
      expect(launched.last, uri);
    }
  });

  test(
    'unsupported, relative, and empty destinations never reach platform',
    () async {
      var calls = 0;
      for (final value in [
        'javascript:alert(1)',
        'file:///tmp/private',
        '/orders/1',
        'https:orders',
        'tel:',
      ]) {
        await expectLater(
          launchBeakUri(
            Uri.parse(value),
            launcher: (_) async {
              calls++;
              return true;
            },
          ),
          throwsA(isA<BeakValidationException>()),
        );
      }
      expect(calls, 0);
    },
  );

  test('missing handlers and platform failures stay typed and safe', () async {
    final uri = Uri.parse('tel:+43123456');
    await expectLater(
      launchBeakUri(uri, launcher: (_) async => false),
      throwsA(isA<BeakValidationException>()),
    );
    await expectLater(
      launchBeakUri(
        uri,
        launcher: (_) async => throw StateError('private platform detail'),
      ),
      throwsA(
        isA<BeakValidationException>().having(
          (e) => e.message,
          'safe message',
          isNot(contains('private')),
        ),
      ),
    );
  });
}
