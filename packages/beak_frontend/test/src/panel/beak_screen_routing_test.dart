import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late FakeDataSource dataSource;

  setUp(() => dataSource = FakeDataSource(records: const {}));

  BeakPanelConfig config({
    List<BeakScreen> pages = const [],
    BeakAuthConfig? auth,
    BeakMaintenanceConfig? maintenance,
    OiThemeMode initialThemeMode = OiThemeMode.light,
  }) => BeakPanelConfig(
    title: 'Demo',
    apiBaseUrl: 'http://localhost',
    resources: const [
      BeakResource(model: NoteModel(), icon: BeakIconToken(OiIcons.file)),
    ],
    pages: pages,
    auth: auth,
    maintenance: maintenance,
    initialThemeMode: initialThemeMode,
  );

  Future<void> pump(WidgetTester tester, BeakPanelConfig panelConfig) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(config: panelConfig, dataSource: dataSource),
    );
    await tester.pumpAndSettle();
  }

  group('custom screens', () {
    const screen = BeakScreen(
      path: '/pricing',
      title: 'Pricing',
      icon: BeakIconToken(OiIcons.tag),
      section: 'Marketing',
      body: BeakColumnBlock(children: [BeakTextBlock('Pick a plan')]),
    );

    testWidgets('a page appears in the nav and routes to its body', (
      tester,
    ) async {
      await pump(tester, config(pages: const [screen]));

      expect(find.text('Pricing'), findsWidgets);

      final BuildContext context = tester.element(find.byType(OiAppShell));
      GoRouter.of(context).go('/pricing');
      await tester.pumpAndSettle();

      expect(find.text('Pick a plan'), findsOneWidget);
    });

    testWidgets('a hidden page routes but has no nav entry', (tester) async {
      const hidden = BeakScreen(
        path: '/secret',
        title: 'Secret',
        icon: BeakIconToken(OiIcons.lock),
        showInNav: false,
        body: BeakTextBlock('hidden body'),
      );
      await pump(tester, config(pages: const [hidden]));

      expect(find.text('Secret'), findsNothing);

      final BuildContext context = tester.element(find.byType(OiAppShell));
      GoRouter.of(context).go('/secret');
      await tester.pumpAndSettle();

      expect(find.text('hidden body'), findsOneWidget);
    });
  });

  group('auth routes', () {
    testWidgets('login always mounts; register/recover follow config', (
      tester,
    ) async {
      await pump(
        tester,
        config(auth: BeakAuthConfig(onLogin: (_, _) async => true)),
      );
      final router = GoRouter.of(tester.element(find.byType(OiAppShell)));

      router.go('/login');
      await tester.pumpAndSettle();
      expect(find.byType(OiAuthPage), findsOneWidget);

      router.go('/register');
      await tester.pumpAndSettle();
      expect(find.byType(OiAuthPage), findsOneWidget);

      router.go('/recover');
      await tester.pumpAndSettle();
      expect(find.byType(OiAuthPage), findsOneWidget);
    });

    testWidgets('register is absent when disabled', (tester) async {
      await pump(tester, config(auth: const BeakAuthConfig(register: false)));
      final router = GoRouter.of(tester.element(find.byType(OiAppShell)));

      router.go('/register');
      await tester.pumpAndSettle();

      // Falls through to the not-found error page.
      expect(find.byType(OiAuthPage), findsNothing);
      expect(find.byType(OiErrorPage), findsOneWidget);
    });
  });

  group('error + maintenance routes', () {
    testWidgets('403 and 500 render typed error pages', (tester) async {
      await pump(tester, config());
      final router = GoRouter.of(tester.element(find.byType(OiAppShell)));

      router.go('/403');
      await tester.pumpAndSettle();
      expect(find.byType(OiErrorPage), findsOneWidget);

      router.go('/500');
      await tester.pumpAndSettle();
      expect(find.byType(OiErrorPage), findsOneWidget);
    });

    testWidgets('maintenance + coming-soon mount when configured', (
      tester,
    ) async {
      await pump(
        tester,
        config(
          maintenance: const BeakMaintenanceConfig(
            maintenanceTitle: 'Back soon',
            comingSoonTitle: 'Launching',
          ),
        ),
      );
      final router = GoRouter.of(tester.element(find.byType(OiAppShell)));

      router.go('/maintenance');
      await tester.pumpAndSettle();
      expect(find.byType(OiMaintenancePage), findsOneWidget);
      expect(find.text('Back soon'), findsWidgets);

      router.go('/coming-soon');
      await tester.pumpAndSettle();
      expect(find.text('Launching'), findsWidgets);
    });
  });

  group('theme toggle', () {
    testWidgets('the shell toggle drives the app theme mode', (tester) async {
      await pump(tester, config(initialThemeMode: OiThemeMode.light));

      final controller = beakLocator<BeakThemeController>();
      expect(controller.value, OiThemeMode.light);

      final toggle = tester.widget<OiThemeToggle>(find.byType(OiThemeToggle));
      expect(toggle.currentMode, OiThemeMode.light);

      controller.value = OiThemeMode.dark;
      await tester.pumpAndSettle();

      final rebuilt = tester.widget<OiThemeToggle>(find.byType(OiThemeToggle));
      expect(rebuilt.currentMode, OiThemeMode.dark);
    });
  });
}
