import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _oddId = 'a/b?c#d%e';

void main() {
  group('BeakRoutes', () {
    test('a record id is one path segment, whatever it contains', () {
      expect(BeakRoutes.show('notes', 7), '/notes/7');
      expect(BeakRoutes.show('notes', _oddId), '/notes/a%2Fb%3Fc%23d%25e');
      expect(BeakRoutes.edit('notes', _oddId), '/notes/a%2Fb%3Fc%23d%25e/edit');
    });

    test('an id that spells another route stays a record id', () {
      expect(BeakRoutes.show('notes', 'x/edit'), '/notes/x%2Fedit');
    });
  });

  group('the return address', () {
    String back(String returnTo) => BeakBackButton.destination(
      Uri(path: '/notes/n1', queryParameters: {'returnTo': returnTo}),
      '/notes',
    );

    test('keeps a local route with its query', () {
      expect(back('/notes?page=2'), '/notes?page=2');
    });

    test('never leaves the panel', () {
      for (final hostile in const [
        'https://evil.example/phish',
        '//evil.example',
        r'/\evil.example',
        'javascript:alert(1)',
        'notes',
        '',
      ]) {
        final destination = back(hostile);
        expect(
          Uri.parse(destination).hasAuthority ||
              Uri.parse(destination).hasScheme,
          isFalse,
          reason: hostile,
        );
        expect(destination, startsWith('/'), reason: hostile);
        expect(destination, isNot(startsWith('//')), reason: hostile);
      }
    });
  });

  group('record routes', () {
    Future<GoRouter> open(WidgetTester tester, String location) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        BeakPanel(
          config: const BeakPanelConfig(
            title: 'Demo',
            resources: [
              BeakResource(
                model: NoteModel(),
                icon: BeakIconToken(OiIcons.notebook),
              ),
            ],
          ),
          dataSource: FakeDataSource(
            records: {
              'notes': {
                _oddId: const BeakRecord(
                  values: {'title': BeakStringValue('Odd one')},
                ),
              },
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(OiAppShell)));
      router.go(location);
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('a record whose id holds reserved characters opens', (
      tester,
    ) async {
      await open(tester, BeakRoutes.show('notes', _oddId));

      expect(
        tester.widget<BeakResourceShowPage>(find.byType(BeakResourceShowPage)),
        isA<BeakResourceShowPage>().having(
          (page) => page.recordId,
          'recordId',
          _oddId,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the edit page of such a record opens as well', (tester) async {
      await open(tester, BeakRoutes.edit('notes', _oddId));

      expect(
        tester.widget<BeakResourceEditPage>(find.byType(BeakResourceEditPage)),
        isA<BeakResourceEditPage>().having(
          (page) => page.recordId,
          'recordId',
          _oddId,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a malformed percent escape does not break the shell', (
      tester,
    ) async {
      await open(tester, '/notes/%zz');

      expect(tester.takeException(), isNull);
      expect(find.byType(OiAppShell), findsOneWidget);
    });
  });
}
