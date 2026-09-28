import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:signals/signals.dart';

import 'beak_auth_view_model_test.dart';
import '../../support/panel_fixtures.dart';

void main() {
  test('disposed router refresh stops observing the auth signal', () {
    final auth = _Auth();
    final guard = BeakAuthRouterRefresh(auth);
    var notifications = 0;
    guard.addListener(() => notifications++);
    auth.snapshot.value = const BeakAuthLoading();
    expect(notifications, 1);
    guard.dispose();
    auth.snapshot.value = const BeakAuthGuest();
    expect(notifications, 1);
  });

  test('guest leaves a previously forbidden page for login', () {
    final auth = _Auth();
    final guard = BeakAuthRouterRefresh(auth);
    addTearDown(guard.dispose);
    expect(guard.redirect('/403'), '/login');
    auth.snapshot.value = const BeakAuthAuthenticated(
      BeakAuthIdentity(id: 'user', canAccessPanel: false),
    );
    expect(guard.redirect('/notes'), '/403');
    expect(guard.redirect('/403'), null);
    auth.snapshot.value = const BeakAuthAuthenticated(
      BeakAuthIdentity(id: 'user'),
    );
    expect(guard.redirect('/login'), '/');
  });

  testWidgets('routed protected state cannot survive a direct account switch', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _Auth();
    auth.snapshot.value = const BeakAuthAuthenticated(
      BeakAuthIdentity(id: 'first'),
    );
    var mounts = 0;
    var disposals = 0;
    await tester.pumpWidget(
      BeakPanel(
        dataSource: FakeDataSource(),
        auth: BeakAuthConfig(adapter: auth),
        pages: [
          BeakScreen(
            path: '/',
            title: 'Home',
            icon: const BeakIconToken(OiIcons.house),
            body: BeakWidgetBlock(
              (context) => HookBuilder(
                builder: (context) {
                  useEffect(() {
                    mounts++;
                    return () => disposals++;
                  }, const []);
                  return const Text('Scoped content');
                },
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(mounts, 1);
    auth.snapshot.value = const BeakAuthAuthenticated(
      BeakAuthIdentity(id: 'second'),
    );
    await tester.pumpAndSettle();
    expect(mounts, 2);
    expect(disposals, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'protected drafts reset for a new identity but survive same-user refresh',
    (tester) async {
      final auth = _Auth();
      auth.snapshot.value = const BeakAuthAuthenticated(
        BeakAuthIdentity(id: 'first'),
      );
      var mounts = 0;
      var disposals = 0;
      await tester.pumpWidget(
        OiApp(
          home: BeakAuthGate(
            adapter: auth,
            child: HookBuilder(
              builder: (context) {
                useEffect(() {
                  mounts++;
                  return () => disposals++;
                }, const []);
                return const Text('Protected draft');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      auth.snapshot.value = const BeakAuthAuthenticated(
        BeakAuthIdentity(id: 'first'),
      );
      await tester.pumpAndSettle();
      expect(mounts, 1);
      expect(disposals, 0);
      auth.snapshot.value = const BeakAuthAuthenticated(
        BeakAuthIdentity(id: 'second'),
      );
      await tester.pumpAndSettle();
      expect(mounts, 2);
      expect(disposals, 1);
      expect(find.text('Protected draft'), findsOneWidget);
    },
  );

  testWidgets('initialization failure hides protected data and can retry', (
    tester,
  ) async {
    final auth = _Auth();
    auth.snapshot.value = const BeakAuthFailure(
      BeakConfigurationException('private details'),
    );
    await tester.pumpWidget(
      OiApp(
        home: BeakAuthGate(adapter: auth, child: const Text('Protected')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Protected'), findsNothing);
    expect(find.text('private details'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Protected'), findsOneWidget);
  });
}

class _Auth extends FakeAuthAdapter {
  final snapshot = signal<BeakAuthState>(const BeakAuthGuest());
  @override
  ReadonlySignal<BeakAuthState> get state => snapshot;
  @override
  Future<BeakResult<void>> refresh() async {
    snapshot.value = const BeakAuthAuthenticated(BeakAuthIdentity(id: 'user'));
    return const BeakOk(null);
  }
}
