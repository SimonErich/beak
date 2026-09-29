import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:signals/signals.dart';

import '../../support/panel_fixtures.dart';
import '../auth/beak_auth_view_model_test.dart';

const _notes = BeakResource(
  model: NoteModel(),
  icon: BeakIconToken(OiIcons.notebook),
);
const _labels = BeakResource(
  model: LabelModel(),
  icon: BeakIconToken(OiIcons.tag),
);
const _private = BeakResource(
  model: _PrivateModel(),
  icon: BeakIconToken(OiIcons.lock),
);
const _reports = BeakScreen(
  path: '/reports',
  title: 'Reports',
  icon: BeakIconToken(OiIcons.barChart2),
  body: BeakTextBlock('reports body'),
);

void main() {
  Future<GoRouter> pump(
    WidgetTester tester,
    BeakPanelConfig config, {
    String? location,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BeakPanel(config: config, dataSource: FakeDataSource()),
    );
    await tester.pumpAndSettle();
    final router = _routerOf(tester);
    if (location != null) {
      router.go(location);
      await tester.pumpAndSettle();
    }
    return router;
  }

  String pathOf(GoRouter router) =>
      router.routeInformationProvider.value.uri.path;

  BeakPanelConfig config({
    List<BeakResource> resources = const [_notes, _labels],
    List<BeakScreen> pages = const [],
    BeakDestination? home,
    BeakNavigation? navigation,
    BeakAuthConfig? auth,
  }) => BeakPanelConfig(
    title: 'Demo',
    resources: resources,
    pages: pages,
    home: home,
    navigation: navigation,
    auth: auth,
  );

  group('the root route', () {
    testWidgets('opens the first resource in navigation order', (tester) async {
      final router = await pump(tester, config());

      expect(pathOf(router), '/notes');
      expect(find.byType(BeakResourceListPage), findsOneWidget);
    });

    testWidgets('follows navigation rank rather than declaration order', (
      tester,
    ) async {
      final router = await pump(
        tester,
        config(resources: [_notes.copyWith(navigationRank: 5), _labels]),
      );

      expect(pathOf(router), '/labels');
    });

    testWidgets('skips a resource the account may not read', (tester) async {
      final router = await pump(
        tester,
        config(resources: const [_private, _labels]),
      );

      expect(pathOf(router), '/labels');
    });

    testWidgets('falls back to the first screen listed in navigation', (
      tester,
    ) async {
      final router = await pump(
        tester,
        config(resources: const [_private], pages: const [_reports]),
      );

      expect(pathOf(router), '/reports');
      expect(find.text('reports body'), findsOneWidget);
    });

    testWidgets('a screen mounted at / keeps the root', (tester) async {
      final router = await pump(
        tester,
        config(
          pages: const [
            BeakScreen(
              path: '/',
              title: 'Overview',
              icon: BeakIconToken(OiIcons.layoutDashboard),
              body: BeakTextBlock('overview body'),
            ),
          ],
        ),
      );

      expect(pathOf(router), '/');
      expect(find.text('overview body'), findsOneWidget);
    });

    testWidgets('a panel showing nothing readable renders the not-found page', (
      tester,
    ) async {
      await pump(tester, config(resources: const [_private]));

      expect(find.byType(OiErrorPage), findsOneWidget);
    });

    test('a panel without resources or pages is a configuration error', () {
      expect(
        () => config(resources: const []).buildRegistry(),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    testWidgets('a navigation section lands on its first visible item', (
      tester,
    ) async {
      final router = await pump(
        tester,
        config(
          navigation: const BeakNavigation(
            sections: [
              BeakNavigationSection(
                key: 'library',
                label: 'Library',
                icon: OiIcons.tag,
                items: [
                  BeakNavigationItem.resource(_PrivateModel()),
                  BeakNavigationItem.resource(LabelModel()),
                ],
              ),
              BeakNavigationSection(
                key: 'content',
                label: 'Content',
                icon: OiIcons.notebook,
                items: [BeakNavigationItem.resource(NoteModel())],
              ),
            ],
          ),
        ),
      );

      expect(pathOf(router), '/labels');
    });
  });

  group('home', () {
    testWidgets('a resource sends / to its list page', (tester) async {
      final router = await pump(tester, config(home: _labels));

      expect(pathOf(router), '/labels');
    });

    testWidgets('a screen sends / to its path', (tester) async {
      final router = await pump(
        tester,
        config(pages: const [_reports], home: _reports),
      );

      expect(pathOf(router), '/reports');
    });

    testWidgets('a hidden resource falls back to the first destination', (
      tester,
    ) async {
      final router = await pump(
        tester,
        config(resources: const [_notes, _private], home: _private),
      );

      expect(pathOf(router), '/notes');
    });

    testWidgets('the panel constructor accepts it directly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        BeakPanel(
          resources: const [_notes, _labels],
          home: _labels,
          dataSource: FakeDataSource(),
        ),
      );
      await tester.pumpAndSettle();

      expect(pathOf(_routerOf(tester)), '/labels');
    });

    test('must name a resource or screen of the panel', () {
      expect(
        () => config(home: _private).buildRegistry(),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => config(home: _reports).buildRegistry(),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => config(pages: const [_reports], home: _reports).buildRegistry(),
        returnsNormally,
      );
    });

    test('cannot compete with a screen mounted at /', () {
      const overview = BeakScreen(
        path: '/',
        title: 'Overview',
        icon: BeakIconToken(OiIcons.layoutDashboard),
        body: BeakTextBlock('overview body'),
      );
      expect(
        () => config(
          pages: const [overview, _reports],
          home: _reports,
        ).buildRegistry(),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => config(pages: const [overview], home: overview).buildRegistry(),
        returnsNormally,
      );
    });

    test('copyWith keeps and replaces it', () {
      final withHome = config(home: _labels);
      expect(withHome.copyWith(title: 'Other').home, same(_labels));
      expect(withHome.copyWith(home: _notes).home, same(_notes));
    });
  });

  group('landing after leaving a page', () {
    testWidgets('the error pages send the user home', (tester) async {
      final router = await pump(
        tester,
        config(home: _labels),
        location: '/unicorns',
      );
      expect(find.byType(OiErrorPage), findsOneWidget);

      await tester.tap(find.text('Back to dashboard'));
      await tester.pumpAndSettle();

      expect(pathOf(router), '/labels');
    });

    testWidgets('signing in lands on the first destination', (tester) async {
      final auth = _SwitchableAuth();
      final router = await pump(
        tester,
        config(auth: BeakAuthConfig(adapter: auth)),
      );
      expect(pathOf(router), '/login');

      auth.signIn();
      await tester.pumpAndSettle();

      expect(pathOf(router), '/notes');
      expect(find.byType(BeakResourceListPage), findsOneWidget);
    });
  });
}

/// An account that can be signed in from the test.
final class _SwitchableAuth extends FakeAuthAdapter {
  final Signal<BeakAuthState> _current = signal(const BeakAuthGuest());

  @override
  ReadonlySignal<BeakAuthState> get state => _current;

  void signIn() =>
      _current.value = const BeakAuthAuthenticated(BeakAuthIdentity(id: 'a'));
}

/// A model whose permissions deny reading, so its resource stays hidden.
final class _PrivateModel extends BeakModel {
  const _PrivateModel();

  @override
  String get table => 'private_notes';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'title', label: 'Title'),
  ];

  @override
  BeakPermissions get permissions =>
      BeakPermissions({BeakOperation.read: () => false});
}

/// The router of whichever top-level page is currently mounted.
GoRouter _routerOf(WidgetTester tester) => GoRouter.of(
  tester.element(
    find.byWidgetPredicate(
      (widget) =>
          widget is OiAppShell ||
          widget is BeakAuthPage ||
          widget is OiErrorPage,
    ),
  ),
);
