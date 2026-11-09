import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

const _viewer = BeakPrincipal(id: 'v', roles: {'viewer'});
const _editor = BeakPrincipal(id: 'e', roles: {'viewer', 'editor'});
const _admin = BeakPrincipal(id: 'a', roles: {'viewer', 'editor', 'admin'});

const _closeOrder = BeakModelAction(name: 'close', label: 'Close');
const _refund = BeakModelAction(name: 'refund', label: 'Refund');

void main() {
  group('role access', () {
    const permissions = BeakPermissions(
      read: BeakAccess.role('viewer'),
      write: BeakAccess.role('editor'),
    );

    test('read follows its own access value', () {
      expect(permissions.allows(BeakOperation.read, _viewer), isTrue);
      expect(permissions.allows(BeakOperation.read, null), isFalse);
    });

    test('create, update and delete default to write', () {
      for (final operation in [
        BeakOperation.create,
        BeakOperation.update,
        BeakOperation.delete,
      ]) {
        expect(
          permissions.allows(operation, _editor),
          isTrue,
          reason: '$operation',
        );
        expect(
          permissions.allows(operation, _viewer),
          isFalse,
          reason: '$operation',
        );
        expect(
          permissions.allows(operation, null),
          isFalse,
          reason: '$operation',
        );
      }
    });
  });

  group('per-operation overrides', () {
    const permissions = BeakPermissions(
      read: BeakAccess.authenticated,
      write: BeakAccess.role('editor'),
      delete: BeakAccess.role('admin'),
      create: BeakAccess.any([
        BeakAccess.role('editor'),
        BeakAccess.role('intern'),
      ]),
    );

    test('an override replaces write for that operation only', () {
      expect(permissions.allows(BeakOperation.delete, _editor), isFalse);
      expect(permissions.allows(BeakOperation.delete, _admin), isTrue);
      expect(permissions.allows(BeakOperation.update, _editor), isTrue);
      expect(permissions.allows(BeakOperation.update, _admin), isTrue);
    });

    test('any combines the roles that may create', () {
      const intern = BeakPrincipal(id: 'i', roles: {'intern'});
      expect(permissions.allows(BeakOperation.create, intern), isTrue);
      expect(permissions.allows(BeakOperation.update, intern), isFalse);
    });
  });

  group('combinators', () {
    test('all needs every role', () {
      const permissions = BeakPermissions(
        read: BeakAccess.all([
          BeakAccess.role('viewer'),
          BeakAccess.role('editor'),
        ]),
      );
      expect(permissions.allows(BeakOperation.read, _editor), isTrue);
      expect(permissions.allows(BeakOperation.read, _viewer), isFalse);
    });

    test('not admits the anonymous request', () {
      const permissions = BeakPermissions(
        read: BeakAccess.not(BeakAccess.authenticated),
      );
      expect(permissions.allows(BeakOperation.read, null), isTrue);
      expect(permissions.allows(BeakOperation.read, _viewer), isFalse);
    });
  });

  group('closed by default', () {
    test('an empty permission denies every operation for everyone', () {
      const permissions = BeakPermissions();
      for (final operation in BeakOperation.values) {
        for (final principal in [null, _viewer, _admin]) {
          expect(permissions.allows(operation, principal), isFalse);
        }
      }
    });

    test('naming only write leaves read denied', () {
      const permissions = BeakPermissions(write: BeakAccess.anyone);
      expect(permissions.allows(BeakOperation.read, _admin), isFalse);
      expect(permissions.allows(BeakOperation.create, null), isTrue);
    });
  });

  group('actions', () {
    const permissions = BeakPermissions(
      read: BeakAccess.authenticated,
      write: BeakAccess.role('editor'),
      update: BeakAccess.role('viewer'),
      actions: {'refund': BeakAccess.role('admin')},
    );

    test('a listed action follows its own access value', () {
      expect(permissions.allowsAction(_refund, _admin), isTrue);
      expect(permissions.allowsAction(_refund, _editor), isFalse);
      expect(permissions.allowsAction(_refund, null), isFalse);
    });

    test('an unlisted action falls back to update, then write', () {
      expect(permissions.allowsAction(_closeOrder, _viewer), isTrue);
      expect(permissions.allowsAction(_closeOrder, null), isFalse);
      const writeOnly = BeakPermissions(write: BeakAccess.role('editor'));
      expect(writeOnly.allowsAction(_closeOrder, _editor), isTrue);
      expect(writeOnly.allowsAction(_closeOrder, _viewer), isFalse);
    });

    test('an empty permission denies every action', () {
      expect(
        const BeakPermissions().allowsAction(_closeOrder, _admin),
        isFalse,
      );
    });
  });

  group('allowAll', () {
    const permissions = BeakPermissions.allowAll();

    test('admits every operation for anyone, anonymous included', () {
      for (final operation in BeakOperation.values) {
        expect(permissions.allows(operation, null), isTrue);
        expect(permissions.allows(operation, _viewer), isTrue);
      }
    });

    test('admits every action', () {
      expect(permissions.allowsAction(_refund, null), isTrue);
    });

    test('is the default of a handwritten model', () {
      expect(
        const _PlainModel().permissions.allows(BeakOperation.read, null),
        isTrue,
      );
    });
  });

  test('permissions are const-constructible and canonicalised', () {
    const first = BeakPermissions(read: BeakAccess.anyone);
    const second = BeakPermissions(read: BeakAccess.anyone);
    expect(identical(first, second), isTrue);
  });
}

final class _PlainModel extends BeakModel {
  const _PlainModel();

  @override
  String get table => 'plain';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
  ];
}
