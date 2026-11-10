import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

enum _Write { config, menu }

enum _Other { only }

const _cancel = BeakModelAction(name: 'cancel', label: 'Cancel');

final class _ConfigModel extends BeakModel {
  const _ConfigModel();

  @override
  String get table => 'config';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakIntColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
  ];

  @override
  Set<BeakOperation> get capabilities => const {
    BeakOperation.read,
    BeakOperation.create,
    BeakOperation.update,
    BeakOperation.delete,
  };

  @override
  BeakAdmission get admission => const BeakAdmission(
    writable: [BeakStringColumn(key: 'name', label: 'Name')],
    write: _Write.config,
  );
}

final class _CommandModel extends BeakModel {
  const _CommandModel();

  @override
  String get table => 'commands';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakIntColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
  ];

  @override
  Set<BeakOperation> get capabilities => const {
    BeakOperation.read,
    BeakOperation.update,
  };

  @override
  BeakAdmission get admission => const BeakAdmission(
    writable: [BeakStringColumn(key: 'name', label: 'Name')],
    write: _Write.menu,
  );

  @override
  BeakModelBehavior get behavior => const BeakModelBehavior(actions: [_cancel]);
}

final class _ReadOnlyModel extends BeakModel {
  const _ReadOnlyModel();

  @override
  String get table => 'read_only';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakIntColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
  ];

  @override
  Set<BeakOperation> get capabilities => const {BeakOperation.read};

  @override
  BeakAdmission get admission => const BeakAdmission(reason: 'Closed.');
}

final class _OtherModel extends BeakModel {
  const _OtherModel();

  @override
  String get table => 'other';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakIntColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
  ];

  @override
  BeakAdmission get admission => const BeakAdmission(write: _Other.only);
}

final class _UnboundModel extends BeakModel {
  const _UnboundModel();

  @override
  String get table => 'unbound';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakIntColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
  ];

  @override
  Set<BeakOperation> get capabilities => const {
    BeakOperation.read,
    BeakOperation.update,
  };

  @override
  BeakAdmission get admission => const BeakAdmission();
}

BeakSaveOperationContext _context({
  String? action,
  Map<String, Object?> values = const {},
}) => BeakSaveOperationContext(
  plan: BeakSavePlan(
    saveId: 'save',
    root: const BeakRecordRef.existing('commands', 1),
    action: action,
    operations: [
      BeakSaveOperation(
        id: 'edit',
        kind: BeakSaveOperationKind.update,
        target: const BeakRecordRef.existing('commands', 1),
        values: BeakRecord.fromRow(values),
      ),
    ],
  ),
  operation: BeakSaveOperation(
    id: 'edit',
    kind: BeakSaveOperationKind.update,
    target: const BeakRecordRef.existing('commands', 1),
    values: BeakRecord.fromRow(values),
  ),
  model: const _CommandModel(),
  values: BeakRecord.fromRow(values),
  existing: null,
  id: 1,
  principal: null,
  transaction: WormDataSource(
    BeakModelRegistry()..register(const _CommandModel()),
    adapter: InMemoryAdapter(),
  ),
);

void main() {
  group('BeakWriteBindings', () {
    BeakWriteBindings<_Write> bindings({
      Map<String, Object?>? captured,
      BeakUnmatched otherwise = BeakUnmatched.stock,
    }) => BeakWriteBindings<_Write>(
      (binding) => switch (binding) {
        _Write.config => const BeakWriteHandler.stock(),
        _Write.menu => BeakWriteHandler.commands(
          actions: {_cancel: (context) async => null},
          otherwise: otherwise,
        ),
      },
    );

    test('accepts a complete binding set', () {
      final registry = BeakModelRegistry()
        ..register(const _ConfigModel())
        ..register(const _CommandModel())
        ..register(const _ReadOnlyModel());

      bindings().validate(registry);
    });

    test('refuses a writable model without a binding', () {
      final registry = BeakModelRegistry()..register(const _UnboundModel());

      expect(
        () => bindings().validate(registry),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('refuses a binding of another enum', () {
      final registry = BeakModelRegistry()..register(const _OtherModel());

      expect(
        () => bindings().validate(registry),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('refuses a command the model does not declare', () {
      final registry = BeakModelRegistry()..register(const _CommandModel());
      final wrong = BeakWriteBindings<_Write>(
        (binding) => BeakWriteHandler.commands(
          actions: {
            const BeakModelAction(
              name: 'explode',
              label: 'Explode',
            ): (context) async =>
                null,
          },
        ),
      );

      expect(
        () => wrong.validate(registry),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('BeakWriteHandler', () {
    test('stock persists the operation the ordinary way', () async {
      expect(await const BeakWriteHandler.stock().run(_context()), isNull);
    });

    test('derive stamps trusted values on a create or update', () async {
      final handler = BeakWriteHandler.derive(
        (context) => const _CommandModel().record([
          const BeakScalarField<String>(
            model: _CommandModel(),
            column: BeakStringColumn(key: 'name', label: 'Name'),
          ).to('stamped'),
        ]),
      );

      final write = await handler.run(_context());
      expect(write?.values?['name']?.raw, 'stamped');
    });

    test('a bound command must be the only operation of the plan', () async {
      final handler = BeakWriteHandler.commands(
        actions: {_cancel: (context) async => null},
      );

      expect(
        () => handler.run(_context(action: 'cancel', values: {'name': 'x'})),
        throwsA(isA<BeakValidationException>()),
      );
    });

    test('a bare command delegates to its handler', () async {
      var ran = false;
      final handler = BeakWriteHandler.commands(
        actions: {
          _cancel: (context) async {
            ran = true;
            return 1;
          },
        },
      );

      final write = await handler.run(_context(action: 'cancel'));
      expect(ran, isTrue);
      expect(write?.persistedId, 1);
    });

    test('otherwise: refuse closes stock persistence', () {
      const handler = BeakWriteHandler.commands(
        otherwise: BeakUnmatched.refuse,
      );

      expect(
        () => handler.run(_context(values: {'name': 'x'})),
        throwsA(isA<BeakValidationException>()),
      );
    });
  });
}
