import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_test/beak_test.dart';
import 'package:beak_test_flutter/beak_test_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../beak_test/test/support/contract_models.dart';

void main() {
  testWidgets('sweeps every visible route at both widths', (tester) async {
    final source = InMemoryBeakDataSource(
      registry: BeakModelRegistry()
        ..register(const ProductModel())
        ..register(const CategoryModel()),
    );
    source.seed(const ProductModel(), [
      BeakRecord.fromRow({
        'id': 'p1',
        'name': 'Espresso',
        'price': 12.5,
        'active': true,
      }),
    ]);
    const config = BeakPanelConfig(
      title: 'Sweep',
      resources: [BeakResource(model: ProductModel(), title: 'Products')],
    );

    final visited = await beakRouteSweep(
      tester,
      config,
      dataSource: source,
      identity: const BeakAuthIdentity(id: 'admin'),
    );

    expect(visited, contains('375:/products'));
    expect(visited, contains('375:/products/p1'));
    expect(visited, contains('1280:/products'));
  });

  testWidgets('stops when the identity sees no route', (tester) async {
    const config = BeakPanelConfig(
      title: 'Sweep',
      resources: [BeakResource(model: _GuardedModel(), title: 'Guarded')],
    );

    final visited = await beakRouteSweep(
      tester,
      config,
      identity: const BeakAuthIdentity(id: 'nobody'),
    );

    expect(visited, isEmpty);
  });
}

final class _GuardedModel extends BeakModel {
  const _GuardedModel();

  @override
  String get table => 'guarded';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
  ];

  @override
  BeakPermissions get permissions =>
      const BeakPermissions(read: BeakAccess.role('reader'));
}
