import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:signals/signals.dart';

import '../../support/panel_fixtures.dart';
import '../auth/beak_auth_view_model_test.dart';

/// An adapter whose session is already open.
final class _SignedIn extends FakeAuthAdapter {
  final Signal<BeakAuthState> _open = signal(
    const BeakAuthAuthenticated(BeakAuthIdentity(id: 'user')),
  );

  @override
  ReadonlySignal<BeakAuthState> get state => _open;
}

void main() {
  BeakPanelConfig config({List<BeakResourceScreen> screens = const []}) =>
      BeakPanelConfig(
        title: 'Demo',
        apiBaseUrl: 'http://localhost',
        resources: [
          BeakResource(
            model: const NoteModel(),
            icon: const BeakIconToken(OiIcons.file),
            screens: screens,
          ),
        ],
        auth: BeakAuthConfig(
          adapter: _SignedIn(),
          idleLockTimeout: const Duration(seconds: 1),
        ),
      );

  Future<GoRouter> open(
    WidgetTester tester,
    BeakPanelConfig panelConfig,
    String path,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(
        config: panelConfig,
        dataSource: FakeDataSource(records: const {}),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(OiAppShell)));
    router.go(path);
    await tester.pumpAndSettle();
    return router;
  }

  String pathOf(GoRouter router) =>
      router.routeInformationProvider.value.uri.path;

  testWidgets('an idle list locks the panel', (tester) async {
    final router = await open(tester, config(), '/notes');

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(pathOf(router), '/lock');
    expect(find.byType(OiAuthPage), findsOneWidget);
  });

  testWidgets('a form with unsaved changes does not hold the lock back', (
    tester,
  ) async {
    final router = await open(tester, config(), '/notes/create');
    await tester.enterText(find.byType(EditableText).first, 'Half a thought');
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(pathOf(router), '/lock');
    expect(find.text('Leave this form?'), findsNothing);
    expect(find.byType(OiAuthPage), findsOneWidget);
  });

  testWidgets('a full-screen form locks too', (tester) async {
    final router = await open(
      tester,
      config(
        screens: const [
          BeakFormScreen(roles: {BeakScreenRole.create}, fullScreen: true),
        ],
      ),
      '/notes/create',
    );
    expect(find.byType(OiAppShell), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(pathOf(router), '/lock');
    expect(find.byType(OiAuthPage), findsOneWidget);
  });

  testWidgets('activity keeps a full-screen form open', (tester) async {
    final router = await open(
      tester,
      config(
        screens: const [
          BeakFormScreen(roles: {BeakScreenRole.create}, fullScreen: true),
        ],
      ),
      '/notes/create',
    );

    // Opening the page used part of the first countdown; the first tap starts
    // a fresh one.
    await tester.tapAt(const Offset(700, 500));
    for (var step = 0; step < 3; step++) {
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tapAt(const Offset(700, 500));
    }
    await tester.pump();

    expect(pathOf(router), '/notes/create');
  });
}
