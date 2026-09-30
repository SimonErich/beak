import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

  test('a locked panel redirects every page to the lock screen', () {
    final auth = _Auth();
    auth.snapshot.value = const BeakAuthAuthenticated(
      BeakAuthIdentity(id: 'user'),
    );
    final guard = BeakAuthRouterRefresh(auth);
    addTearDown(guard.dispose);
    var notifications = 0;
    guard.addListener(() => notifications++);

    guard.lock();

    expect(guard.locked, isTrue);
    expect(notifications, 1);
    expect(guard.redirect('/notes'), '/lock');
    expect(guard.redirect('/login'), '/lock');
    expect(guard.redirect('/lock'), null);

    guard.unlock();

    expect(guard.locked, isFalse);
    expect(guard.redirect('/notes'), null);
  });

  test('a failed refresh does not lift the lock', () {
    final auth = _Auth();
    auth.snapshot.value = const BeakAuthAuthenticated(
      BeakAuthIdentity(id: 'user'),
    );
    final guard = BeakAuthRouterRefresh(auth);
    addTearDown(guard.dispose);
    guard.lock();

    auth.snapshot.value = const BeakAuthFailure(
      BeakTransportException('offline'),
    );
    auth.snapshot.value = const BeakAuthLoading();
    auth.snapshot.value = const BeakAuthAuthenticated(
      BeakAuthIdentity(id: 'user'),
    );

    expect(guard.locked, isTrue);
    expect(guard.redirect('/notes'), '/lock');
  });

  test('a lock cannot be taken out on nobody', () {
    final guard = BeakAuthRouterRefresh(_Auth());
    addTearDown(guard.dispose);

    guard.lock();

    expect(guard.locked, isFalse);
  });

  test('a different account does not inherit the lock', () {
    final auth = _Auth();
    auth.snapshot.value = const BeakAuthAuthenticated(
      BeakAuthIdentity(id: 'user'),
    );
    final guard = BeakAuthRouterRefresh(auth);
    addTearDown(guard.dispose);
    guard.lock();

    auth.snapshot.value = const BeakAuthAuthenticated(
      BeakAuthIdentity(id: 'other'),
    );

    expect(guard.locked, isFalse);
  });

  test('signing out ends the lock', () {
    final auth = _Auth();
    auth.snapshot.value = const BeakAuthAuthenticated(
      BeakAuthIdentity(id: 'user'),
    );
    final guard = BeakAuthRouterRefresh(auth);
    addTearDown(guard.dispose);
    guard.lock();

    auth.snapshot.value = const BeakAuthGuest();
    auth.snapshot.value = const BeakAuthAuthenticated(
      BeakAuthIdentity(id: 'other'),
    );

    expect(guard.locked, isFalse);
    expect(guard.redirect('/notes'), null);
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

  group('the 403 page offers a way out', () {
    Future<_Auth> parked(WidgetTester tester, {required bool access}) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final auth = _Auth();
      auth.snapshot.value = BeakAuthAuthenticated(
        BeakAuthIdentity(id: 'user', canAccessPanel: access),
      );
      await tester.pumpWidget(
        BeakPanel(
          dataSource: FakeDataSource(),
          auth: BeakAuthConfig(adapter: auth),
          resources: const [BeakResource(model: NoteModel())],
        ),
      );
      await tester.pumpAndSettle();
      return auth;
    }

    testWidgets('an account without panel access can sign out from it', (
      tester,
    ) async {
      final auth = await parked(tester, access: false);

      expect(find.text('403'), findsWidgets);
      expect(find.text('Back to dashboard'), findsNothing);
      await tester.tap(find.text('Back to sign in'));
      await tester.pumpAndSettle();

      expect(auth.loggedOut, isTrue);
      expect(find.byType(BeakAuthPage), findsOneWidget);
    });

    testWidgets(
      'a forbidden page of an admitted account returns to the panel',
      (tester) async {
        await parked(tester, access: true);
        GoRouter.of(tester.element(find.byType(OiAppShell))).go('/403');
        await tester.pumpAndSettle();

        expect(find.text('Back to sign in'), findsNothing);
        await tester.tap(find.text('Back to dashboard'));
        await tester.pumpAndSettle();

        expect(find.byType(OiAppShell), findsOneWidget);
      },
    );
  });

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
  bool loggedOut = false;
  @override
  ReadonlySignal<BeakAuthState> get state => snapshot;
  @override
  Future<BeakResult<void>> logout() async {
    loggedOut = true;
    snapshot.value = const BeakAuthGuest();
    return const BeakOk(null);
  }

  @override
  Future<BeakResult<void>> refresh() async {
    snapshot.value = const BeakAuthAuthenticated(BeakAuthIdentity(id: 'user'));
    return const BeakOk(null);
  }
}
