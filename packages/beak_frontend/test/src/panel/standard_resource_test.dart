import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';

enum _Status { active, retired }

final class _ProductModel extends BeakModel {
  const _ProductModel();

  @override
  String get table => 'products';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
    BeakEnumColumn<_Status>(
      key: 'status',
      label: 'Status',
      values: _Status.values,
    ),
  ];
}

void main() {
  tearDown(() => BeakLabels.current = const BeakLabels());

  test('standard builds a list and a form with default list settings', () {
    final resource = BeakResource.standard(const _ProductModel(), 'Products');
    final list = resource.screenFor(BeakScreenRole.list);
    final form = resource.screenFor(BeakScreenRole.read);

    expect(list, isA<BeakTableScreen>());
    expect(form, isA<BeakFormScreen>());
    expect(resource.canCreate, isTrue);
    expect(
      (list! as BeakTableScreen).definition?.pageSize,
      const BeakListDefaults().pageSize,
    );
  });

  test('a read-only standard resource offers reads only', () {
    final resource = BeakResource.standard(
      const _ProductModel(),
      'Products',
      readOnly: true,
    );

    expect(resource.canCreate, isFalse);
    expect(resource.canEdit, isFalse);
    expect(resource.canDelete, isFalse);
  });

  test('one label mapping renames enums, columns and commands', () {
    BeakLabels.current = BeakLabels(
      enumValue: (value) => value == _Status.active ? 'Active' : null,
      field: (column) => column.key == 'name' ? 'Title' : null,
      action: (action) => 'Run ${action.name}',
    );
    const model = _ProductModel();
    final status = model.columnByKey('status')! as BeakEnumColumn<_Status>;

    expect(status.labelFor(_Status.active), 'Active');
    expect(model.columnByKey('name')!.label, 'Title');
    expect(
      const BeakModelAction(name: 'publish', label: 'Publish').label,
      'Run publish',
    );
  });
}
