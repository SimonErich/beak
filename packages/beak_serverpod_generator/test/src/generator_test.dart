import 'dart:io';

import 'package:beak_serverpod_generator/beak_serverpod_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'unsupported models fail explicitly before any output is written',
    () async {
      for (final model in [
        'Unsupported',
        'Positional',
        'NullableChildren',
        'Missing',
      ]) {
        await expectLater(
          generateServerpodCompanions(
            packageRoot: Directory.current.path,
            library: Uri.file(
              p.absolute('test/fixtures/models.dart'),
            ).toString(),
            types: [model],
          ),
          throwsA(isA<FormatException>()),
        );
      }
      await expectLater(
        generateServerpodCompanions(
          packageRoot: Directory.current.path,
          library: 'package:missing/missing.dart',
          types: ['Missing'],
        ),
        throwsA(isA<FormatException>()),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'resolves inherited/imported/nested fields and emits compilable codecs',
    () async {
      final output = await generateServerpodCompanions(
        packageRoot: Directory.current.path,
        library: Uri.file(p.absolute('test/fixtures/models.dart')).toString(),
        types: ['View', 'Input', 'Create', 'Collision'],
      );
      expect(output, contains('accountCreatedAt'));
      expect(output, contains('aliasName'));
      expect(output, contains('ServerpodField<'));
      expect(output, contains('ServerpodCodecs.uuid.list'));
      expect(output, isNot(contains('toJson()')));
      expect(output, isNot(contains('dynamic')));
      final generated = File('test/fixtures/models.beak.g.dart');
      final runner = File('test/fixtures/verify.dart');
      addTearDown(() {
        if (generated.existsSync()) generated.deleteSync();
        if (runner.existsSync()) runner.deleteSync();
      });
      generated.writeAsStringSync(output);
      runner.writeAsStringSync('''
import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod/beak_serverpod.dart';
import 'package:uuid/uuid_value.dart';
import 'models.dart';
import 'models.beak.g.dart';
void main() {
  final id = UuidValue.fromString('c4263bc1-cad9-453f-b4fa-e49891f8f824');
  final account = Account(id: id, createdAt: DateTime.utc(2026));
  final original = View(account: account, status: Status.open, members: [account]);
  final row = const ViewCodec().encode(original);
  if (ViewFields.accountId.read(row) != id) throw StateError('UUID projection');
  if (ViewFields.aliasName.read(row) != null) throw StateError('null projection');
  final decoded = const ViewCodec().decode(row);
  if (decoded.account.createdAt != original.account.createdAt) throw StateError('inherited date');
  if (ViewRelations.members.read(row)?.single.id != id) throw StateError('typed object list');
  final collision = const CollisionCodec().encode(Collision(account: account, accountId: 'label'));
  if (CollisionFields.account__id.read(collision) != id || CollisionFields.accountId.read(collision) != 'label') throw StateError('path collision');
  final status = ViewFields.status.column('Status', options: ServerpodColumnOptions(enumLabels: {Status.open: 'Offen'}));
  if (status is! BeakEnumColumn<Status> || status.labelFor(Status.open) != 'Offen') throw StateError('localized enum');
  final input = const CreateCodec().decode(BeakRecord(values: {
    'input.name': const BeakNullValue(), 'input.active': const BeakBoolValue(false),
    'input.ids': BeakListValue([BeakStringValue(id.uuid)]),
    'password': const BeakStringValue('example'),
  }));
  if (input.input.active != false || input.input.name != null || input.input.ids.single != id) throw StateError('typed input');
  try {
    const InputCodec().decode(BeakRecord(values: {
      'active': const BeakNullValue(), 'ids': const BeakListValue([]),
    }));
    throw StateError('missing nullable required input accepted');
  } on BeakValidationException { }
}
''');
      final execution = await Process.run(Platform.resolvedExecutable, [
        'run',
        runner.path,
      ]);
      expect(
        execution.exitCode,
        0,
        reason: '${execution.stdout}\n${execution.stderr}',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('imports a model through the public library that exports it', () async {
    final library = Uri.file(p.absolute('test/fixtures/public/api.dart'));
    final output = await generateServerpodCompanions(
      packageRoot: Directory.current.path,
      library: library.toString(),
      types: ['Thing'],
    );

    expect(
      output,
      contains(RegExp("import '${RegExp.escape('$library')}'\\s+as i0;")),
    );
    expect(output, isNot(contains('src/thing.dart')));
  });

  test('the header names the tool without a dash and silences the lint the '
      'collision names trip', () async {
    final output = await generateServerpodCompanions(
      packageRoot: Directory.current.path,
      library: Uri.file(p.absolute('test/fixtures/models.dart')).toString(),
      types: ['Collision'],
    );

    expect(output, startsWith('// GENERATED BY beak_serverpod_generator.'));
    expect(output, isNot(contains('\u2014')));
    expect(
      output,
      contains('// ignore_for_file: non_constant_identifier_names'),
    );
    expect(output, contains('account__id'));
  });
}
