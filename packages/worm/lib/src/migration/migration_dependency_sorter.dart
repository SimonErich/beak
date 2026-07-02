/// Topological sort over [Migration.dependsOn] with cycle
/// detection.
library;

import '../exception/migration_exception.dart';
import 'migration_base.dart';

/// Topologically orders [Migration]s so each migration runs after
/// every entry it declares in [Migration.dependsOn]. Throws a
/// [MigrationException] when a dependency cycle is present; the
/// exception message names every migration that participates in
/// the cycle.
///
/// Migrations with empty [Migration.dependsOn] retain their
/// registration order — the sort is a stable Kahn-style toposort
/// driven by the input order's positions, so default callers see
/// no behavioral change.
abstract final class MigrationDependencySorter {
  /// Returns [migrations] sorted by dependency order.
  static List<Migration> sort(List<Migration> migrations) {
    if (migrations.isEmpty) return const <Migration>[];
    final byName = <String, Migration>{for (final m in migrations) m.name: m};
    final order = <String, int>{
      for (var i = 0; i < migrations.length; i++) migrations[i].name: i,
    };
    final remainingDeps = _buildRemainingDeps(migrations, byName);
    final result = _kahn(migrations, byName, remainingDeps, order);
    if (result.length == migrations.length) return result;
    throw _cycleException(migrations, remainingDeps);
  }

  static Map<String, Set<String>> _buildRemainingDeps(
    List<Migration> migrations,
    Map<String, Migration> byName,
  ) {
    final remaining = <String, Set<String>>{
      for (final m in migrations) m.name: <String>{},
    };
    for (final m in migrations) {
      for (final dep in m.dependsOn) {
        if (!byName.containsKey(dep)) {
          throw MigrationException(
            migration: m.name,
            message: 'declares unknown dependency "$dep"',
          );
        }
        remaining[m.name]?.add(dep);
      }
    }
    return remaining;
  }

  static List<Migration> _kahn(
    List<Migration> migrations,
    Map<String, Migration> byName,
    Map<String, Set<String>> remainingDeps,
    Map<String, int> registrationOrder,
  ) {
    final ready = <String>[
      for (final m in migrations)
        if (remainingDeps[m.name]?.isEmpty ?? true) m.name,
    ]..sort((a, b) => registrationOrder[a]!.compareTo(registrationOrder[b]!));
    final result = <Migration>[];
    final dependents = _buildDependentsIndex(migrations);
    while (ready.isNotEmpty) {
      final name = ready.removeAt(0);
      final node = byName[name];
      if (node != null) result.add(node);
      for (final dependentName in dependents[name] ?? const <String>{}) {
        final deps = remainingDeps[dependentName];
        if (deps == null) continue;
        deps.remove(name);
        if (deps.isEmpty) {
          _insertOrdered(ready, dependentName, registrationOrder);
        }
      }
    }
    return result;
  }

  static Map<String, Set<String>> _buildDependentsIndex(
    List<Migration> migrations,
  ) {
    final dependents = <String, Set<String>>{
      for (final m in migrations) m.name: <String>{},
    };
    for (final m in migrations) {
      for (final dep in m.dependsOn) {
        dependents.putIfAbsent(dep, () => <String>{}).add(m.name);
      }
    }
    return dependents;
  }

  static void _insertOrdered(
    List<String> queue,
    String name,
    Map<String, int> order,
  ) {
    final pos = order[name] ?? -1;
    var i = 0;
    while (i < queue.length && (order[queue[i]] ?? -1) <= pos) {
      i++;
    }
    queue.insert(i, name);
  }

  static MigrationException _cycleException(
    List<Migration> migrations,
    Map<String, Set<String>> remainingDeps,
  ) {
    final stuck = <String>[
      for (final m in migrations)
        if ((remainingDeps[m.name] ?? const <String>{}).isNotEmpty) m.name,
    ];
    final namesList = stuck.map((n) => "'$n'").join(', ');
    return MigrationException(
      migration: stuck.isEmpty ? 'unknown' : stuck.first,
      message:
          'Dependency cycle detected among migrations: '
          '$namesList. Break the cycle by removing one of the '
          'dependsOn entries.',
    );
  }
}
