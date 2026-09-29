import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:signals/signals.dart';

import '../auth/beak_auth_view_model_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late FakeDataSource dataSource;

  setUp(() => dataSource = FakeDataSource(records: const {}));

  BeakPanelConfig config({
    List<BeakResource>? resources,
    List<BeakScreen> pages = const [],
    BeakAuthConfig? auth,
    BeakMaintenanceConfig? maintenance,
    OiThemeMode initialThemeMode = OiThemeMode.light,
  }) => BeakPanelConfig(
    title: 'Demo',
    apiBaseUrl: 'http://localhost',
    resources:
        resources ??
        const [
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

  testWidgets('record action roles follow list routes and live form modes', (
    tester,
  ) async {
    dataSource = FakeDataSource(
      records: {
        'notes': {
          'n1': BeakRecord.fromRow({'id': 'n1', 'title': 'Mode test'}),
        },
      },
    );
    await pump(
      tester,
      config(
        resources: [
          BeakResource(
            model: const NoteModel(),
            screens: const [
              BeakFormScreen(roles: {BeakScreenRole.read, BeakScreenRole.edit}),
            ],
            recordActions: [
              for (final role in [
                BeakScreenRole.list,
                BeakScreenRole.read,
                BeakScreenRole.edit,
              ])
                BeakRecordAction(
                  key: role.name,
                  label: '${role.name} helper',
                  roles: {role},
                  onExecute: (_, _) async {},
                ),
              BeakRecordAction(
                key: 'all',
                label: 'All modes',
                onExecute: (_, _) async {},
              ),
            ],
          ),
        ],
      ),
    );
    final router = GoRouter.of(tester.element(find.byType(OiAppShell)));
    router.go('/notes');
    await tester.pumpAndSettle();
    final listActions = tester
        .widget<BeakDataTable>(find.byType(BeakDataTable))
        .actions;
    expect(
      listActions.map((action) => action.label),
      containsAll(['list helper', 'All modes']),
    );
    expect(
      listActions.map((action) => action.label),
      isNot(contains('read helper')),
    );
    expect(
      listActions.map((action) => action.label),
      isNot(contains('edit helper')),
    );
    router.go('/notes/n1');
    await tester.pumpAndSettle();
    expect(find.text('read helper'), findsOneWidget);
    expect(find.text('edit helper'), findsNothing);
    expect(find.text('All modes'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('read helper'), findsNothing);
    expect(find.text('edit helper'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('read helper'), findsOneWidget);
    expect(find.text('edit helper'), findsNothing);
    router.go('/notes/n1/edit');
    await tester.pumpAndSettle();
    expect(find.text('read helper'), findsNothing);
    expect(find.text('edit helper'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('custom screens', () {
    const screen = BeakScreen(
      path: '/pricing',
      title: 'Pricing',
      icon: BeakIconToken(OiIcons.tag),
      navigationGroup: 'Marketing',
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

    test('the sidebar title defaults to the title', () {
      expect(screen.effectiveNavigationTitle, 'Pricing');
      expect(screen.location, '/pricing');
      const renamed = BeakScreen(
        path: '/pricing',
        title: 'Pricing',
        navigationTitle: 'Plans',
        icon: BeakIconToken(OiIcons.tag),
        body: BeakTextBlock('Pick a plan'),
      );
      expect(renamed.effectiveNavigationTitle, 'Plans');
    });

    testWidgets('a page is filed under its navigation group', (tester) async {
      await pump(
        tester,
        config(
          pages: const [
            BeakScreen(
              path: '/pricing',
              title: 'Pricing',
              navigationTitle: 'Plans',
              navigationGroup: 'Marketing',
              icon: BeakIconToken(OiIcons.tag),
              body: BeakTextBlock('Pick a plan'),
            ),
          ],
        ),
      );

      expect(find.text('Plans'), findsOneWidget);
      expect(find.text('Marketing'), findsWidgets);
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
    testWidgets('permission refresh preserves an open form and its draft', (
      tester,
    ) async {
      final auth = _TestAuth(signedIn: true);
      await pump(tester, config(auth: BeakAuthConfig(adapter: auth)));
      final router = GoRouter.of(tester.element(find.byType(OiAppShell)));
      router.go('/notes/create');
      await tester.pumpAndSettle();
      final input = find.byType(EditableText).first;
      await tester.enterText(input, 'Unsaved draft');
      final controller = tester.widget<EditableText>(input).controller;
      final formElement = tester.element(find.byType(BeakConfiguredForm));
      auth.snapshot.value = const BeakAuthAuthenticated(
        BeakAuthIdentity(id: 'test', displayName: 'Updated account'),
      );
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/notes/create');
      expect(
        tester.element(find.byType(BeakConfiguredForm)),
        same(formElement),
      );
      expect(tester.widget<EditableText>(input).controller, same(controller));
      expect(controller.text, 'Unsaved draft');
    });

    for (final path in ['/notes', '/notes/n1']) {
      testWidgets(
        'write revocation refreshes controls at $path without navigation',
        (tester) async {
          final auth = _TestAuth(signedIn: true);
          auth.snapshot.value = const BeakAuthAuthenticated(
            _Permissions(write: true),
          );
          bool canWrite() => switch (auth.snapshot.value) {
            BeakAuthAuthenticated(identity: _Permissions(:final write)) =>
              write,
            _ => false,
          };
          dataSource = FakeDataSource(
            records: {
              'notes': {
                'n1': BeakRecord.fromRow({'id': 'n1', 'title': 'Visible note'}),
              },
            },
          );
          await pump(
            tester,
            config(
              auth: BeakAuthConfig(adapter: auth),
              resources: [
                BeakResource(
                  model: _WriteGatedNoteModel(canWrite),
                  icon: const BeakIconToken(OiIcons.file),
                ),
              ],
            ),
          );
          final router = GoRouter.of(tester.element(find.byType(OiAppShell)));
          router.go(path);
          await tester.pumpAndSettle();
          expect(find.byType(BeakActionButton), findsWidgets);
          auth.snapshot.value = const BeakAuthAuthenticated(
            _Permissions(write: false),
          );
          await tester.pumpAndSettle();
          expect(router.routeInformationProvider.value.uri.path, path);
          expect(find.byType(BeakActionButton), findsNothing);
          if (path == '/notes') {
            expect(
              tester
                  .widget<BeakDataTable>(find.byType(BeakDataTable))
                  .actions
                  .map((action) => action.id),
              ['view'],
            );
          }
          expect(find.text('Visible note'), findsWidgets);
        },
      );
    }

    testWidgets(
      'logout returns to login and protected direct URLs stay guarded',
      (tester) async {
        final auth = _TestAuth(signedIn: true);
        await pump(tester, config(auth: BeakAuthConfig(adapter: auth)));
        final router = GoRouter.of(tester.element(find.byType(OiAppShell)));
        expect(find.text('Sign out'), findsOneWidget);
        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();
        expect(find.byType(BeakAuthPage), findsOneWidget);
        router.go('/notes/n1/edit');
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/login');
        expect(find.byType(OiAppShell), findsNothing);
      },
    );

    testWidgets(
      'missing backend capabilities do not expose enabled signup/reset',
      (tester) async {
        await pump(
          tester,
          config(
            auth: BeakAuthConfig(
              adapter: FakeAuthAdapter(),
              register: true,
              recover: true,
            ),
          ),
        );
        final router = GoRouter.of(tester.element(find.byType(BeakAuthPage)));
        expect(find.text('Forgot password?'), findsNothing);
        expect(find.text('Create account'), findsNothing);
        router.go('/recover');
        await tester.pumpAndSettle();
        expect(find.byType(OiErrorPage), findsOneWidget);
        router.go('/register');
        await tester.pumpAndSettle();
        expect(find.byType(OiErrorPage), findsOneWidget);
      },
    );

    testWidgets('login always mounts; register/recover follow config', (
      tester,
    ) async {
      await pump(
        tester,
        config(
          auth: BeakAuthConfig(
            adapter: _TestAuth(),
            register: true,
            recover: true,
          ),
        ),
      );
      final router = GoRouter.of(tester.element(find.byType(BeakAuthPage)));

      router.go('/login');
      await tester.pumpAndSettle();
      expect(find.byType(BeakAuthPage), findsOneWidget);

      router.go('/register');
      await tester.pumpAndSettle();
      expect(find.byType(BeakAuthPage), findsOneWidget);

      router.go('/recover');
      await tester.pumpAndSettle();
      expect(find.byType(BeakAuthPage), findsOneWidget);
    });

    testWidgets('register is absent when disabled', (tester) async {
      await pump(tester, config(auth: const BeakAuthConfig(register: false)));
      final router = GoRouter.of(tester.element(find.byType(BeakAuthPage)));

      router.go('/register');
      await tester.pumpAndSettle();

      // Falls through to the not-found error page.
      expect(find.byType(BeakAuthPage), findsNothing);
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

    testWidgets('redirectTo sends every other route to the chosen page', (
      tester,
    ) async {
      await pump(
        tester,
        config(
          maintenance: const BeakMaintenanceConfig(
            maintenanceTitle: 'Back soon',
            comingSoonTitle: 'Launching',
            redirectTo: BeakMaintenancePage.maintenance,
          ),
        ),
      );
      final router = GoRouter.of(
        tester.element(find.byType(OiMaintenancePage)),
      );

      expect(find.text('Back soon'), findsWidgets);
      router.go('/notes');
      await tester.pumpAndSettle();
      expect(find.text('Back soon'), findsWidgets);
      expect(find.byType(BeakResourceListPage), findsNothing);

      // The other page stays reachable, so a launch page can be previewed.
      router.go('/coming-soon');
      await tester.pumpAndSettle();
      expect(find.text('Launching'), findsWidgets);
    });

    testWidgets('a coming-soon redirect wins over the sign-in wall', (
      tester,
    ) async {
      final adapter = FakeAuthAdapter();
      await pump(
        tester,
        config(
          auth: BeakAuthConfig(adapter: adapter),
          maintenance: const BeakMaintenanceConfig(
            comingSoonTitle: 'Launching',
            redirectTo: BeakMaintenancePage.comingSoon,
          ),
        ),
      );

      expect(find.text('Launching'), findsWidgets);
      expect(find.byType(OiMaintenancePage), findsOneWidget);
    });
  });

  group('theme toggle', () {
    testWidgets('the shell toggle drives the app theme mode', (tester) async {
      await pump(tester, config(initialThemeMode: OiThemeMode.light));

      final controller = beakDependencies(
        tester.element(find.byType(OiAppShell)),
      )<BeakThemeController>();
      expect(controller.value, OiThemeMode.light);

      final toggle = tester.widget<OiThemeToggle>(find.byType(OiThemeToggle));
      expect(toggle.currentMode, OiThemeMode.light);

      controller.value = OiThemeMode.dark;
      await tester.pumpAndSettle();

      final rebuilt = tester.widget<OiThemeToggle>(find.byType(OiThemeToggle));
      expect(rebuilt.currentMode, OiThemeMode.dark);
    });
  });

  group('idle lock', () {
    testWidgets('the lock route renders the lock screen', (tester) async {
      await pump(
        tester,
        config(auth: BeakAuthConfig(adapter: _TestAuth(signedIn: true))),
      );
      GoRouter.of(tester.element(find.byType(OiAppShell))).go('/lock');
      await tester.pumpAndSettle();

      expect(find.byType(OiAppShell), findsNothing);
      expect(find.byType(OiAuthPage), findsOneWidget);
    });

    testWidgets('the panel auto-locks after the idle timeout', (tester) async {
      await pump(
        tester,
        config(
          auth: BeakAuthConfig(
            adapter: _TestAuth(signedIn: true),
            idleLockTimeout: const Duration(seconds: 1),
            lockUserName: 'Aisha',
          ),
        ),
      );
      expect(find.byType(OiAppShell), findsOneWidget);

      // No activity → the idle timer fires and navigates to the lock screen.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.byType(OiAppShell), findsNothing);
      expect(find.byType(OiAuthPage), findsOneWidget);
    });
  });
}

class _Permissions extends BeakAuthIdentity {
  const _Permissions({required this.write}) : super(id: 'test');
  final bool write;
}

class _TestAuth extends FakeAuthAdapter {
  _TestAuth({bool signedIn = false})
    : snapshot = signal(
        signedIn
            ? const BeakAuthAuthenticated(BeakAuthIdentity(id: 'test'))
            : const BeakAuthGuest(),
      );
  final Signal<BeakAuthState> snapshot;
  @override
  ReadonlySignal<BeakAuthState> get state => snapshot;
  @override
  BeakEmailVerificationFlow Function()? get registration => FakeEmailFlow.new;
  @override
  BeakEmailVerificationFlow Function()? get recovery => FakeEmailFlow.new;
  @override
  Future<BeakResult<void>> logout() async {
    snapshot.value = const BeakAuthGuest();
    return const BeakOk(null);
  }
}

/// The notes model whose write permissions follow a live account check.
final class _WriteGatedNoteModel extends BeakModel {
  const _WriteGatedNoteModel(this.canWrite);

  final bool Function() canWrite;

  @override
  String get table => 'notes';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'title', label: 'Title', searchable: true),
  ];

  @override
  BeakPermissions get permissions => BeakPermissions({
    BeakOperation.read: () => true,
    BeakOperation.create: canWrite,
    BeakOperation.update: canWrite,
    BeakOperation.delete: canWrite,
  });
}
