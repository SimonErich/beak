import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:signals/signals.dart';

import 'package:beak_test/beak_test.dart' show InMemoryBeakDataSource;

/// Visits every route a panel offers and fails on a rendering error.
///
/// The sweep mounts [config] at each of [sizes] and opens every visible list,
/// create, show and edit route for the resources and pages [identity] may see.
/// It catches the failures that only appear on a real screen: an overflow at a
/// narrow width, a form that throws while building a field, a detail page that
/// breaks on a missing record.
///
/// ```dart
/// testWidgets('every route renders', (tester) async {
///   await beakRouteSweep(
///     tester,
///     shopConfig,
///     identity: const BeakAuthIdentity(
///       id: 'admin',
///       roles: {'adminRead', 'adminWrite'},
///     ),
///   );
/// });
/// ```
///
/// [dataSource] supplies real rows; without one an empty
/// [InMemoryBeakDataSource] still visits every route. A detail route for a
/// model with no row uses its primary key's sentinel, which is the page's
/// not-found path, not a different route.
Future<List<String>> beakRouteSweep(
  WidgetTester tester,
  BeakPanelConfig config, {
  BeakDataSource? dataSource,
  List<Size> sizes = const [Size(375, 800), Size(1280, 900)],
  BeakAuthIdentity? identity,
}) => _sweep(
  tester,
  config: config,
  dataSource: dataSource,
  sizes: sizes,
  identity: identity,
  panel: (key, auth, source) => BeakPanel(
    key: key,
    config: auth == null ? config : config.copyWith(auth: auth),
    dataSource: source,
  ),
);

/// [beakRouteSweep] for a panel whose configuration is built in a localized
/// context, as `runServerpodBeakAdmin` and [BeakLocalizedPanel] build it.
///
/// [config] is called with a context holding [localizationsDelegates] for
/// [locale], the same way the running panel calls it, so the sweep also
/// proves the app's copy resolves:
///
/// ```dart
/// await beakLocalizedRouteSweep(
///   tester,
///   (context) => shopConfig(context),
///   locale: const Locale('de'),
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
/// );
/// ```
Future<List<String>> beakLocalizedRouteSweep(
  WidgetTester tester,
  BeakPanelConfigBuilder config, {
  Locale locale = const Locale('en'),
  List<Locale>? supportedLocales,
  Iterable<LocalizationsDelegate<Object?>> localizationsDelegates = const [],
  BeakDataSource? dataSource,
  List<Size> sizes = const [Size(375, 800), Size(1280, 900)],
  BeakAuthIdentity? identity,
}) async {
  final locales = supportedLocales ?? [locale];
  // The routes come from the built configuration, so build it once in the
  // context the panel will give it.
  late BeakPanelConfig built;
  await tester.pumpWidget(
    Localizations(
      locale: locale,
      delegates: [
        ...localizationsDelegates,
        BeakLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      child: Builder(
        builder: (context) {
          BeakLabels.language = locale.languageCode;
          built = config(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return _sweep(
    tester,
    config: built,
    dataSource: dataSource,
    sizes: sizes,
    identity: identity,
    panel: (key, auth, source) => BeakLocalizedPanel(
      key: key,
      locale: locale,
      supportedLocales: locales,
      localizationsDelegates: localizationsDelegates,
      config: (context) {
        final panel = config(context);
        return auth == null ? panel : panel.copyWith(auth: auth);
      },
      dataSource: source,
    ),
  );
}

Future<List<String>> _sweep(
  WidgetTester tester, {
  required BeakPanelConfig config,
  required BeakDataSource? dataSource,
  required List<Size> sizes,
  required BeakAuthIdentity? identity,
  required Widget Function(Key key, BeakAuthConfig? auth, BeakDataSource source)
  panel,
}) async {
  final access = BeakPanelAccess.fixed(identity?.principal);
  final auth = identity == null
      ? null
      : BeakAuthConfig(adapter: _SweepAuthAdapter(identity));
  final source =
      dataSource ?? InMemoryBeakDataSource(registry: config.buildRegistry());
  final visited = <String>[];
  for (final size in sizes) {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(panel(ValueKey(size), auth, source));
    await tester.pumpAndSettle();
    if (find.byType(OiAppShell).evaluate().isEmpty) return visited;
    final router = GoRouter.of(tester.element(find.byType(OiAppShell)));
    for (final path in await _visiblePaths(config, access, source)) {
      router.go(path);
      await tester.pumpAndSettle();
      final error = tester.takeException();
      if (error != null) {
        throw TestFailure('$path threw at ${size.width}px: $error');
      }
      if (find.byType(ErrorWidget).evaluate().isNotEmpty) {
        throw TestFailure('$path rendered an ErrorWidget at ${size.width}px.');
      }
      visited.add('${size.width.toInt()}:$path');
    }
  }
  return visited;
}

Future<List<String>> _visiblePaths(
  BeakPanelConfig config,
  BeakPanelAccess access,
  BeakDataSource source,
) async {
  final paths = <String>[];
  for (final resource in config.navigationResources) {
    if (!resource.isVisibleTo(access)) continue;
    paths.add(resource.route);
    final model = resource.model;
    if (resource.allowsCreateTo(access)) {
      paths.add('${resource.route}/create');
    }
    if (!resource.allowsEditTo(access) && !resource.isVisibleTo(access)) {
      continue;
    }
    final id = await _firstId(model, source);
    paths.add('${resource.route}/$id');
    if (resource.allowsEditTo(access)) paths.add('${resource.route}/$id/edit');
  }
  for (final screen in config.pages) {
    if (screen.showInNav && screen.isAccessibleTo(access)) {
      paths.add(screen.path);
    }
  }
  return paths;
}

Future<Object> _firstId(BeakModel model, BeakDataSource source) async {
  try {
    final page = await source.query(
      model.query(pagination: const BeakPagination(perPage: 1)),
    );
    final record = page.items.firstOrNull;
    final id = record == null ? null : model.primaryKeyOf(record);
    if (id != null) return id;
  } on Object {
    // An empty or unreachable source still has a not-found detail page.
  }
  return switch (model.primaryKey) {
    BeakIntColumn() => 0,
    _ => 'sweep',
  };
}

final class _SweepAuthAdapter extends BeakAuthAdapter {
  _SweepAuthAdapter(this.identity)
    : _state = signal<BeakAuthState>(BeakAuthAuthenticated(identity));

  final BeakAuthIdentity identity;
  final Signal<BeakAuthState> _state;

  @override
  ReadonlySignal<BeakAuthState> get state => _state;

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
