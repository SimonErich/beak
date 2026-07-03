import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  const config = BeakPanelConfig(
    title: 'Beak Admin',
    apiBaseUrl: 'http://localhost:8080',
    resources: [
      BeakResource(model: NoteModel(), icon: BeakIconToken(OiIcons.notebook)),
      BeakResource(
        model: LabelModel(),
        icon: BeakIconToken(OiIcons.tag),
        label: 'Tags',
      ),
    ],
  );

  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(config: config, dataSource: FakeDataSource()),
    );
    await tester.pumpAndSettle();
  }

  GoRouter routerOf(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(OiAppShell)));

  Future<void> go(WidgetTester tester, String location) async {
    routerOf(tester).go(location);
    await tester.pumpAndSettle();
  }

  group('shell', () {
    testWidgets('renders one nav item per resource plus the dashboard', (
      tester,
    ) async {
      await pumpPanel(tester);

      expect(find.byType(OiAppShell), findsOneWidget);
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);
    });

    testWidgets('renders no Material or Cupertino widgets', (tester) async {
      await pumpPanel(tester);

      const banned = {
        'Material',
        'Scaffold',
        'AppBar',
        'ElevatedButton',
        'TextField',
        'CupertinoApp',
        'CupertinoPageScaffold',
        'MaterialApp',
      };
      final offenders = tester.allWidgets
          .where((widget) => banned.contains(widget.runtimeType.toString()))
          .toList();
      expect(offenders, isEmpty, reason: 'obers_ui only — no Material');
    });

    testWidgets('sidebar navigation drives the router', (tester) async {
      await pumpPanel(tester);

      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      expect(
        find.text('The Notes list page arrives in Phases 12–14.'),
        findsOneWidget,
      );
    });
  });

  group('generated routes', () {
    testWidgets('every resource gets list/create/show/edit routes', (
      tester,
    ) async {
      await pumpPanel(tester);

      await go(tester, '/notes');
      expect(
        find.text('The Notes list page arrives in Phases 12–14.'),
        findsOneWidget,
      );

      await go(tester, '/notes/create');
      expect(
        find.text('The Notes create page arrives in Phases 12–14.'),
        findsOneWidget,
      );

      await go(tester, '/notes/n1');
      expect(find.text('Notes n1'), findsOneWidget);
      expect(
        find.text('The Notes show page arrives in Phases 12–14.'),
        findsOneWidget,
      );

      await go(tester, '/notes/n1/edit');
      expect(
        find.text('The Notes edit page arrives in Phases 12–14.'),
        findsOneWidget,
      );

      await go(tester, '/labels');
      expect(
        find.text('The Tags list page arrives in Phases 12–14.'),
        findsOneWidget,
      );
    });

    testWidgets('the login route renders the auth page outside the shell', (
      tester,
    ) async {
      await pumpPanel(tester);
      await go(tester, '/login');

      expect(find.byType(OiAuthPage), findsOneWidget);
      expect(find.byType(OiAppShell), findsNothing);
    });

    testWidgets('unknown locations render the typed not-found page', (
      tester,
    ) async {
      await pumpPanel(tester);
      routerOf(tester).go('/unicorns');
      await tester.pumpAndSettle();

      expect(find.byType(OiErrorPage), findsOneWidget);
    });
  });

  group('dependency registration', () {
    testWidgets('the panel registers the data layer in the Beak locator', (
      tester,
    ) async {
      await pumpPanel(tester);

      expect(beakLocator<BeakClient>(), isNotNull);
      expect(beakLocator<ReferenceCache>(), isNotNull);
      expect(beakLocator<BeakPanelConfig>().title, 'Beak Admin');
    });
  });
}
