import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod_server/beak_serverpod_server.dart';
import 'package:serverpod/serverpod.dart' show UuidValue;
import 'package:test/test.dart';

const _archive = BeakModelAction(name: 'archive', label: 'Archive');

final class _Model extends BeakModel {
  const _Model();

  @override
  String get table => 'sample';

  @override
  String get displayColumnKey => 'id';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
  ];

  @override
  BeakModelBehavior get behavior =>
      const BeakModelBehavior(actions: [_archive]);
}

void main() {
  test('a UUID text becomes a UuidValue; anything else is refused', () {
    const text = '0193b1a2-7c1d-7b6e-9f00-0123456789ab';

    expect(BeakServerpodValues.uuid(text), UuidValue.withValidation(text));
    expect(BeakServerpodValues.uuid(UuidValue.withValidation(text)).uuid, text);
    expect(BeakServerpodValues.uuidOrNull(null), isNull);
    expect(
      () => BeakServerpodValues.uuid('nope'),
      throwsA(isA<BeakValidationException>()),
    );
    expect(
      () => BeakServerpodValues.uuid(7),
      throwsA(isA<BeakValidationException>()),
    );
  });

  test('a command binds to the action the model declares', () {
    Future<Object?> run(BeakSaveOperationContext context) async => null;

    final bound = beakServerpodCommands(const _Model(), {'archive': run});

    expect(bound.keys.single.name, 'archive');
  });

  test('a command the model does not declare fails at startup', () {
    Future<Object?> run(BeakSaveOperationContext context) async => null;

    expect(
      () => beakServerpodCommands(const _Model(), {'publish': run}),
      throwsA(
        isA<BeakConfigurationException>().having(
          (error) => error.message,
          'message',
          contains('"publish"'),
        ),
      ),
    );
  });
}
