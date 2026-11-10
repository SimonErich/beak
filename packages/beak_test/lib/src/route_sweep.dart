import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'in_memory_beak_data_source.dart';

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
}) async {
  final access = BeakPanelAccess.fixed(identity?.principal);
  final adapter = identity == null ? null : _SweepAuthAdapter(identity);
  final source =
      dataSource ?? InMemoryBeakDataSource(registry: config.buildRegistry());
  final visited = <String>[];
  for (final size in sizes) {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final swept = identity == null
        ? config
        : config.copyWith(auth: BeakAuthConfig(adapter: adapter));
    await tester.pumpWidget(
      BeakPanel(key: ValueKey(size), config: swept, dataSource: source),
    );
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
      visited.add('${size.width}:$path');
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
    : _state = ValueNotifier<BeakAuthState>(
        BeakAuthAuthenticated(identity),
      );

  final BeakAuthIdentity identity;
  final ValueNotifier<BeakAuthState> _state;

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
