import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  test('permission callbacks are live and missing rules deny', () {
    var canEdit = false;
    final permissions = BeakPermissions({
      BeakOperation.read: () => true,
      BeakOperation.update: () => canEdit,
    });
    expect(permissions.allows(BeakOperation.read), isTrue);
    expect(permissions.allows(BeakOperation.update), isFalse);
    expect(permissions.allows(BeakOperation.delete), isFalse);
    canEdit = true;
    expect(permissions.allows(BeakOperation.update), isTrue);
  });

  test('unrestricted default preserves handwritten and generated models', () {
    const permissions = BeakPermissions.allowAll();
    for (final operation in BeakOperation.values) {
      expect(permissions.allows(operation), isTrue);
    }
  });
}
