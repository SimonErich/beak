import 'dart:io';

import 'package:beak_cli/beak_cli.dart';
import 'package:test/test.dart';

const String noteModel = '''
import 'package:beak_core/beak_core.dart';

final class NoteModel extends BeakModel {
  const NoteModel();
  @override
  String get table => 'notes';
  @override
  String get displayColumnKey => 'title';
  @override
  List<BeakColumn> get columns => const [];
}
''';

/// A project directory seeded with [files].
Directory projectWith(Map<String, String> files) {
  final root = Directory.systemTemp.createTempSync('beak_doctor_');
  addTearDown(() => root.deleteSync(recursive: true));
  for (final MapEntry(key: path, value: contents) in files.entries) {
    final file = File('${root.path}/$path');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }
  return root;
}

BeakCliEnvironment environmentFor(
  Directory root, {
  bool databaseUp = false,
  StringSink? out,
}) => BeakCliEnvironment(
  out: out ?? StringBuffer(),
  rootDirectory: root,
  now: () => DateTime.utc(2026, 7, 26, 12),
  probe: (host, port) async => databaseUp,
);

/// The check whose label contains [needle].
BeakCheck checkMatching(List<BeakCheck> checks, String needle) =>
    checks.firstWhere(
      (check) => check.label.contains(needle),
      orElse: () => throw StateError(
        'no check matching "$needle" in:\n'
        '${checks.map((check) => '  ${check.label}').join('\n')}',
      ),
    );

/// A minimal but complete project: pubspec, model, generated wiring.
Directory preparedProject() {
  final root = projectWith({
    'pubspec.yaml': 'name: acme_admin\ndependencies:\n  beak: ^0.9.0\n',
    'lib/models/note.dart': noteModel,
  });
  runPrepare(environmentFor(root));
  return root;
}

void main() {
  group('not a project', () {
    test('is the only check reported, with the fix', () async {
      final checks = await diagnose(environmentFor(projectWith({})));
      expect(checks, hasLength(1));
      expect(checks.single.status, BeakCheckStatus.fail);
      expect(checks.single.remedy, contains('beak create'));
    });
  });

  group('dependencies', () {
    test('a project not depending on Beak fails', () async {
      final checks = await diagnose(
        environmentFor(projectWith({'pubspec.yaml': 'name: acme_admin\n'})),
      );
      expect(
        checkMatching(checks, 'does not depend on beak').status,
        BeakCheckStatus.fail,
      );
    });

    test('a project depending on Beak passes', () async {
      final checks = await diagnose(environmentFor(preparedProject()));
      expect(
        checkMatching(checks, 'depends on Beak').status,
        BeakCheckStatus.ok,
      );
    });
  });

  group('beak.yaml', () {
    test('a malformed file fails, and stops further checks', () async {
      final root = projectWith({
        'pubspec.yaml': 'name: acme_admin\ndependencies:\n  beak:\n',
        'beak.yaml': 'colour: blue\n',
      });
      final checks = await diagnose(environmentFor(root));
      expect(checkMatching(checks, 'colour').status, BeakCheckStatus.fail);
      // Nothing downstream can be trusted once config parsing failed.
      expect(
        checks.where((check) => check.label.contains('discovered')),
        isEmpty,
      );
    });
  });

  group('models', () {
    test('an empty project warns rather than failing', () async {
      final root = projectWith({
        'pubspec.yaml': 'name: acme_admin\ndependencies:\n  beak:\n',
      });
      final checks = await diagnose(environmentFor(root));
      final check = checkMatching(checks, 'no models found');
      expect(check.status, BeakCheckStatus.warn);
      expect(check.remedy, contains('lib/models/'));
    });

    test('a discovery issue is surfaced as a failure', () async {
      final root = projectWith({
        'pubspec.yaml': 'name: acme_admin\ndependencies:\n  beak:\n',
        'lib/models/note.dart': '''
import 'package:beak_core/beak_core.dart';

final class NoteModel extends BeakModel {
  NoteModel(this.table);
  @override
  final String table;
}
''',
      });
      final checks = await diagnose(environmentFor(root));
      expect(
        checkMatching(checks, 'const NoteModel()').status,
        BeakCheckStatus.fail,
      );
    });
  });

  group('generated files', () {
    test('a prepared project reports them up to date', () async {
      final checks = await diagnose(environmentFor(preparedProject()));
      expect(
        checkMatching(checks, 'generated files up to date').status,
        BeakCheckStatus.ok,
      );
    });

    test('a stale file fails, naming `beak prepare` as the fix', () async {
      final root = preparedProject();
      File(
        '${root.path}/lib/beak/registry.g.dart',
      ).writeAsStringSync('// hand-edited\n');

      final checks = await diagnose(environmentFor(root));
      final check = checkMatching(checks, 'out of date');
      expect(check.status, BeakCheckStatus.fail);
      expect(check.remedy, 'beak prepare');
      expect(check.label, contains('1 stale'));
    });

    test('a missing entrypoint fails — the fresh-clone case', () async {
      final root = preparedProject();
      File('${root.path}/lib/main.dart').deleteSync();

      final check = checkMatching(
        await diagnose(environmentFor(root)),
        'out of date',
      );
      expect(check.status, BeakCheckStatus.fail);
      expect(check.label, contains('1 missing'));
    });
  });

  group('database', () {
    test('an absent DATABASE_URL warns, it does not fail', () async {
      final check = checkMatching(
        await diagnose(environmentFor(preparedProject())),
        'no DATABASE_URL',
      );
      expect(check.status, BeakCheckStatus.warn);
    });

    test('an unreachable database warns with the two possible fixes', () async {
      final root = preparedProject();
      File('${root.path}/.env').writeAsStringSync(
        'DATABASE_URL=postgres://beak:beak@localhost:25432/beak\n',
      );
      final check = checkMatching(
        await diagnose(environmentFor(root)),
        'database unreachable',
      );
      expect(check.status, BeakCheckStatus.warn);
      expect(check.label, contains('localhost:25432'));
      expect(check.remedy, contains('DATABASE_URL'));
    });

    test('a reachable database passes', () async {
      final root = preparedProject();
      File('${root.path}/.env').writeAsStringSync(
        'DATABASE_URL=postgres://beak:beak@localhost:25432/beak\n',
      );
      final check = checkMatching(
        await diagnose(environmentFor(root, databaseUp: true)),
        'database reachable',
      );
      expect(check.status, BeakCheckStatus.ok);
    });
  });

  group('exit code', () {
    test('is 0 when only warnings are present', () async {
      final out = StringBuffer();
      final code = await createBeakRunner(
        environmentFor(preparedProject(), out: out),
      ).run(['doctor']);
      expect(code, 0, reason: 'warnings must not fail the command');
      expect(out.toString(), contains('All checks passed.'));
    });

    test('is 1 when any check failed', () async {
      final root = preparedProject();
      File('${root.path}/lib/main.dart').deleteSync();
      final out = StringBuffer();
      final code = await createBeakRunner(
        environmentFor(root, out: out),
      ).run(['doctor']);
      expect(code, 1);
      expect(out.toString(), contains('Some checks failed.'));
      expect(out.toString(), contains('→ beak prepare'));
    });
  });
}
