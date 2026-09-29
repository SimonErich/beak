import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_frontend/src/data/model_beak_data_source.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

/// A source that refuses every read with a mapped authentication failure.
final class _Refusing extends FakeDataSource {
  _Refusing(this.failure);

  final Exception failure;

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async => throw failure;
}

void main() {
  ModelBeakDataSource routerOver(
    BeakDataSource source, {
    required void Function() onUnauthorized,
    BeakException? Function(Exception, StackTrace)? mapException,
  }) => ModelBeakDataSource(
    registry: BeakModelRegistry()..register(const NoteModel()),
    fallback: source,
    overrideBindings: true,
    onUnauthorized: onUnauthorized,
    mapException: mapException,
  );

  group('ModelBeakDataSource.onUnauthorized', () {
    test('runs when a source refuses with an authentication failure', () async {
      var calls = 0;
      final router = routerOver(
        _Refusing(const BeakAuthenticationException('Expired.')),
        onUnauthorized: () => calls++,
      );
      addTearDown(router.dispose);

      await expectLater(
        router.query(const BeakQuerySpec(table: 'notes')),
        throwsA(isA<BeakAuthenticationException>()),
      );
      expect(calls, 1);
    });

    test(
      'runs for a host failure mapped to an authentication failure',
      () async {
        var calls = 0;
        final router = routerOver(
          _Refusing(const FormatException('host says 401')),
          onUnauthorized: () => calls++,
          mapException: (error, _) => error is FormatException
              ? const BeakAuthenticationException('Expired.')
              : null,
        );
        addTearDown(router.dispose);

        await expectLater(
          router.query(const BeakQuerySpec(table: 'notes')),
          throwsA(isA<BeakAuthenticationException>()),
        );
        expect(calls, 1);
      },
    );

    test('stays quiet for every other failure', () async {
      var calls = 0;
      final router = routerOver(
        _Refusing(const BeakAuthorizationException('Not yours.')),
        onUnauthorized: () => calls++,
      );
      addTearDown(router.dispose);

      await expectLater(
        router.query(const BeakQuerySpec(table: 'notes')),
        throwsA(isA<BeakAuthorizationException>()),
      );
      expect(calls, 0);
    });
  });

  testWidgets('a 401 from the API signs the panel out', (tester) async {
    final requests = <String>[];
    final client = MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      return switch (request.url.path) {
        '/api/auth/login' => http.Response(
          jsonEncode({
            'token': 'expired-token',
            'principal': {'id': 'user', 'roles': <String>[]},
          }),
          200,
        ),
        '/api/auth/logout' => http.Response('', 204),
        _ => http.Response('', 401),
      };
    });
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(
        config: const BeakPanelConfig(
          title: 'Demo',
          apiBaseUrl: 'http://example.test',
          resources: [BeakResource(model: NoteModel())],
          auth: BeakAuthConfig(),
        ),
        httpClient: client,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).first, 'admin');
    await tester.enterText(find.byType(EditableText).last, 'secret');
    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();

    expect(requests, contains('POST /api/notes/query'));
    expect(requests, contains('POST /api/auth/logout'));
    expect(find.byType(BeakAuthPage), findsOneWidget);
    expect(find.byType(OiAppShell), findsNothing);
  });
}
