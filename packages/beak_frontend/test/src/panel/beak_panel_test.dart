import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:signals/signals_flutter.dart';

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
        title: 'Tags',
      ),
    ],
  );

  Future<void> pumpPanel(WidgetTester tester, {FakeDataSource? source}) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(config: config, dataSource: source ?? FakeDataSource()),
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
    testWidgets('mounted screens follow reactive access revocation', (
      tester,
    ) async {
      final allowed = signal(true);
      addTearDown(allowed.dispose);
      final screen = BeakScreen(
        path: '/live',
        title: 'Live',
        icon: const BeakIconToken(OiIcons.lock),
        canAccess: () => allowed.value,
        body: const BeakTextBlock('Protected content'),
      );
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakScreenView(screen: screen),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Protected content'), findsOneWidget);
      allowed.value = false;
      await tester.pumpAndSettle();
      expect(find.text('Protected content'), findsNothing);
      expect(find.byType(OiErrorPage), findsOneWidget);
    });

    testWidgets(
      'screen access guards navigation, commands and direct routes live',
      (tester) async {
        var allowed = false;
        final screen = BeakScreen(
          path: '/protected',
          title: 'Protected page',
          icon: const BeakIconToken(OiIcons.lock),
          canAccess: () => allowed,
          body: const BeakTextBlock('Protected content'),
        );
        final gated = config.copyWith(pages: [screen]);
        await tester.pumpWidget(
          BeakPanel(config: gated, dataSource: FakeDataSource()),
        );
        await tester.pumpAndSettle();
        final router = routerOf(tester);
        expect(find.text('Protected page'), findsNothing);
        expect(
          beakNavigationCommands(
            gated,
            (_) {},
          ).any((command) => command.id == 'nav:/protected'),
          isFalse,
        );
        router.go('/protected');
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/403');
        expect(find.text('Protected content'), findsNothing);
        allowed = true;
        router.go('/protected');
        await tester.pumpAndSettle();
        expect(find.text('Protected content'), findsOneWidget);
        expect(
          beakNavigationCommands(
            gated,
            (_) {},
          ).any((command) => command.id == 'nav:/protected'),
          isTrue,
        );
        allowed = false;
        router.refresh();
        await tester.pumpAndSettle();
        expect(find.text('Protected content'), findsNothing);
        expect(find.byType(OiErrorPage), findsOneWidget);
        await tester.pumpWidget(
          OiApp(
            theme: OiThemeData.light(),
            home: BeakScreenView(screen: screen),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Protected content'), findsNothing);
        expect(find.byType(OiErrorPage), findsOneWidget);
      },
    );

    testWidgets('renders one nav item per resource and no dashboard item', (
      tester,
    ) async {
      await pumpPanel(tester);

      expect(find.byType(OiAppShell), findsOneWidget);
      expect(find.text('Dashboard'), findsNothing);
      expect(find.text('Notes'), findsWidgets);
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

      await tester.tap(find.text('Tags'));
      await tester.pumpAndSettle();

      expect(find.byType(BeakResourceListPage), findsOneWidget);
      expect(
        routerOf(tester).routeInformationProvider.value.uri.path,
        '/labels',
      );
    });
  });

  group('generated routes', () {
    testWidgets(
      'resource capabilities are reevaluated after permissions change',
      (tester) async {
        final auth = _RoleAuth({'writer'});
        await tester.pumpWidget(
          BeakPanel(
            config: config.copyWith(
              auth: BeakAuthConfig(adapter: auth),
              resources: [
                config.resources.first.copyWith(
                  model: const _WriteGatedNoteModel(),
                ),
              ],
            ),
            dataSource: FakeDataSource(),
          ),
        );
        await tester.pumpAndSettle();
        final router = routerOf(tester);
        router.go('/notes/create');
        await tester.pumpAndSettle();
        expect(find.byType(BeakResourceCreatePage), findsOneWidget);

        auth.grant(const {});
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/403');
        expect(find.byType(BeakResourceCreatePage), findsNothing);
        expect(find.byType(OiErrorPage), findsOneWidget);

        router.go('/notes/create');
        await tester.pumpAndSettle();
        expect(find.byType(BeakResourceCreatePage), findsNothing);
        expect(find.byType(OiErrorPage), findsOneWidget);
      },
    );
    testWidgets('custom create and edit workflows keep resource routes', (
      tester,
    ) async {
      await tester.pumpWidget(
        BeakPanel(
          config: config.copyWith(
            resources: [
              config.resources.first.copyWith(
                screens: [
                  BeakCustomResourceScreen(
                    roles: const {BeakScreenRole.create},
                    builder: (_, _) => const Text('Checkout workflow'),
                  ),
                  BeakCustomResourceScreen(
                    roles: const {BeakScreenRole.edit},
                    builder: (_, id) => Text('Edit items $id'),
                  ),
                ],
              ),
            ],
          ),
          dataSource: FakeDataSource(),
        ),
      );
      await tester.pumpAndSettle();
      final router = routerOf(tester);
      router.go('/notes/create');
      await tester.pumpAndSettle();
      expect(find.text('Checkout workflow'), findsOneWidget);
      router.go('/notes/n1/edit');
      await tester.pumpAndSettle();
      expect(find.text('Edit items n1'), findsOneWidget);
    });

    testWidgets('read-only resources hide writes and reject write routes', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        BeakPanel(
          config: config.copyWith(
            resources: [
              config.resources.first.copyWith(
                canCreate: false,
                canEdit: false,
                canDelete: false,
              ),
            ],
          ),
          dataSource: FakeDataSource(),
        ),
      );
      await tester.pumpAndSettle();
      final router = routerOf(tester);
      router.go('/notes');
      await tester.pumpAndSettle();
      expect(find.text('Create'), findsNothing);
      router.go('/notes/n1');
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      router.go('/notes/create');
      await tester.pumpAndSettle();
      expect(find.byType(BeakResourceCreatePage), findsNothing);
      expect(find.byType(OiErrorPage), findsOneWidget);
      router.go('/notes/n1/edit');
      await tester.pumpAndSettle();
      expect(find.byType(BeakResourceEditPage), findsNothing);
    });

    testWidgets('host router owns authentication and the app root', (
      tester,
    ) async {
      // --8<-- [start:hostRouter]
      registerBeakDependencies(config: config, dataSource: FakeDataSource());
      final router = GoRouter(
        initialLocation: '/notes',
        routes: [
          GoRoute(
            path: '/sign-in',
            builder: (_, _) => const Text('Host login'),
          ),
          ShellRoute(
            redirect: (_, _) => '/sign-in',
            builder: (_, _, child) => child,
            routes: beakPanelRoutes(config),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(OiApp.router(routerConfig: router));
      // --8<-- [end:hostRouter]
      await tester.pumpAndSettle();
      expect(find.text('Host login'), findsOneWidget);
      expect(find.byType(OiApp), findsOneWidget);
      expect(find.byType(BeakResourceListPage), findsNothing);
    });

    testWidgets('every resource gets list/create/show/edit routes', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        source: FakeDataSource(
          records: {
            'notes': {
              'n1': BeakRecord.fromRow(const {'id': 'n1', 'title': 'First'}),
            },
          },
        ),
      );

      await go(tester, '/notes');
      expect(find.byType(BeakResourceListPage), findsOneWidget);

      await go(tester, '/notes/create');
      expect(find.byType(BeakResourceCreatePage), findsOneWidget);

      await go(tester, '/notes/n1');
      expect(find.text('Notes n1'), findsWidgets);
      expect(find.byType(BeakResourceShowPage), findsOneWidget);

      await go(tester, '/notes/n1/edit');
      expect(find.byType(BeakResourceEditPage), findsOneWidget);

      await go(tester, '/labels');
      expect(find.byType(BeakResourceListPage), findsOneWidget);
      expect(find.text('Tags'), findsWidgets);
    });

    testWidgets('the login route renders the auth page outside the shell', (
      tester,
    ) async {
      await pumpPanel(tester);
      await go(tester, '/login');

      expect(find.byType(BeakAuthPage), findsOneWidget);
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
    test(
      'external sessions do not create a second auth store or HTTP client',
      () async {
        final locator = GetIt.asNewInstance();
        registerBeakDependencies(
          config: config,
          dataSource: FakeDataSource(),
          locator: locator,
          externalAuthentication: true,
        );
        expect(locator.isRegistered<BeakSessionStore>(), isFalse);
        expect(locator.isRegistered<BeakClient>(), isFalse);
        expect(locator.isRegistered<BeakDataSource>(), isTrue);
        await locator.reset();
      },
    );

    testWidgets('the panel registers the data layer in its own scope', (
      tester,
    ) async {
      await pumpPanel(tester);

      final dependencies = beakDependencies(
        tester.element(find.byType(OiAppShell)),
      );
      expect(dependencies<BeakClient>(), isNotNull);
      expect(dependencies<BeakPanelConfig>().title, 'Beak Admin');
    });
  });

  group('the resources shorthand', () {
    BeakException? mapper(Exception error, StackTrace stack) => null;

    test('carries mapException and maintenance into its configuration', () {
      const maintenance = BeakMaintenanceConfig(
        redirectTo: BeakMaintenancePage.maintenance,
      );
      final panel = BeakPanel(
        resources: config.resources,
        mapException: mapper,
        maintenance: maintenance,
      );

      expect(panel.config.mapException, same(mapper));
      expect(panel.config.maintenance, same(maintenance));
    });

    test('a bare panel keeps the default title and API origin', () {
      final panel = BeakPanel(resources: config.resources);

      expect(panel.config.title, 'Beak');
      expect(panel.config.apiBaseUrl, 'http://localhost:8080');
    });

    test('rejects shorthand options that a given config would ignore', () {
      final panel = BeakPanel(
        config: config,
        title: 'Other',
        theme: OiThemeData.light(),
        mapException: mapper,
      );

      expect(
        () => panel.config,
        throwsA(
          isA<BeakConfigurationException>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('title'),
              contains('theme'),
              contains('mapException'),
              contains('BeakPanelConfig'),
            ),
          ),
        ),
      );
    });

    test('a given config still takes the data and transport seams', () {
      final panel = BeakPanel(config: config, dataSource: FakeDataSource());

      expect(panel.config, same(config));
    });
  });
}

// --8<-- [start:WriteGatedNoteModel]
/// The notes model whose writes are open to the `writer` role.
final class _WriteGatedNoteModel extends BeakModel {
  const _WriteGatedNoteModel();

  @override
  String get table => 'notes';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => const NoteModel().columns;

  @override
  BeakPermissions get permissions => const BeakPermissions(
    read: BeakAccess.anyone,
    write: BeakAccess.role('writer'),
  );
}
// --8<-- [end:WriteGatedNoteModel]

/// A signed-in account whose roles the test changes while the panel runs.
final class _RoleAuth extends BeakAuthAdapter {
  _RoleAuth(Set<String> roles)
    : _state = signal(
        BeakAuthAuthenticated(BeakAuthIdentity(id: 'writer-1', roles: roles)),
      );

  final Signal<BeakAuthState> _state;

  @override
  ReadonlySignal<BeakAuthState> get state => _state;

  void grant(Set<String> roles) => _state.value = BeakAuthAuthenticated(
    BeakAuthIdentity(id: 'writer-1', roles: roles),
  );

  @override
  Future<BeakResult<void>> login({
    required String email,
    required String password,
  }) async => const BeakOk(null);

  @override
  Future<BeakResult<void>> logout() async => const BeakOk(null);

  @override
  Future<BeakResult<void>> refresh() async => const BeakOk(null);
}
