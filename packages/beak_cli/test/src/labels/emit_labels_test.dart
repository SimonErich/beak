import 'package:beak_cli/src/labels/project_labels.dart';
import 'package:beak_cli/src/schema/beak_schema_emitter.dart';
import 'package:beak_cli/src/schema/beak_schema_ir.dart';
import 'package:test/test.dart';

const _command = BeakSchemaIr(
  className: 'AccountRoleCommand',
  table: 'input_account_role_command',
  libraryPath: 'src/access/account_role_command.dart',
  displayColumnKey: 'roleId',
  softDeletes: false,
  timestamps: false,
  managesSchema: false,
  columns: [
    BeakColumnIr(
      fieldName: 'roleId',
      columnKey: 'roleId',
      label: 'Role Id',
      kind: BeakColumnKind.string,
      isRequired: true,
    ),
  ],
  relations: [],
);

void main() {
  test('a command input carries its names and field labels', () {
    final source = BeakSchemaEmitter.emitServerpodInputPart(
      const BeakGeneratedInput(_command),
      const <BeakGeneratedModel>[],
      labels: const BeakProjectLabels(
        template: 'de',
        bySchema: {
          'AccountRoleCommand': BeakSchemaLabels(
            one: {'de': 'Rollenänderung', 'en': 'Role change'},
            fields: {
              'roleId': {'de': 'Rolle', 'en': 'Role'},
            },
          ),
        },
      ),
    );

    expect(source, contains('BeakModelLabels get labels'));
    expect(
      source,
      contains("one: {'de': 'Rollenänderung', 'en': 'Role change'}"),
    );
    expect(source, contains("label: 'Rolle',"));
    expect(source, contains("translations: {'de': 'Rolle', 'en': 'Role'},"));
  });
}
