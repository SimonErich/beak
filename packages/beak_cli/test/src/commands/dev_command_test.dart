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

void main() {
  late Directory root;
  late StringBuffer out;
  late List<List<String>> spawned;

  setUp(() {
    root = Directory.systemTemp.createTempSync('beak_dev_');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/pubspec.yaml').writeAsStringSync('name: acme_admin\n');
    File('${root.path}/lib/models/note.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(noteModel);
    out = StringBuffer();
    spawned = [];
  });

  BeakCliEnvironment environment({int exitCode = 0}) => BeakCliEnvironment(
    out: out,
    rootDirectory: root,
    now: () => DateTime.utc(2026, 7, 26, 12),
    probe: (host, port) async => false,
    runProcess: (executable, arguments, {workingDirectory}) async {
      spawned.add([executable, ...arguments]);
      return exitCode;
    },
  );

  Future<int> run(List<String> args, {int exitCode = 0}) async =>
      await createBeakRunner(environment(exitCode: exitCode)).run(args) ?? 0;

  group('dev', () {
    test('regenerates, then serves the API', () async {
      expect(await run(['dev']), 0);
      expect(
        File('${root.path}/lib/beak/registry.g.dart').existsSync(),
        isTrue,
      );
      expect(spawned.single, ['dart', 'run', 'bin/serve.dart']);
    });

    test('prints the flutter run line rather than proxying it', () async {
      await run(['dev', '-d', 'linux']);
      expect(out.toString(), contains('flutter run -d linux'));
    });

    test('--no-serve only regenerates', () async {
      expect(await run(['dev', '--no-serve']), 0);
      expect(spawned, isEmpty);
      expect(File('${root.path}/lib/main.dart').existsSync(), isTrue);
    });

    test('a generation failure stops before spawning anything', () async {
      File('${root.path}/lib/models/broken.dart').writeAsStringSync('''
import 'package:beak_core/beak_core.dart';

final class BrokenModel extends BeakModel {
  BrokenModel(this.table);
  @override
  final String table;
}
''');
      expect(await run(['dev']), 1);
      expect(spawned, isEmpty);
      expect(out.toString(), contains('Cannot generate'));
    });

    test('surfaces the server exit code', () async {
      expect(await run(['dev'], exitCode: 70), 70);
    });
  });

  group('migrate', () {
    test('regenerates, then delegates to the project CLI', () async {
      expect(await run(['migrate']), 0);
      expect(spawned.single, ['dart', 'run', 'bin/migrate.dart', 'migrate']);
    });

    test('passes a subcommand through', () async {
      await run(['migrate', 'fresh']);
      expect(spawned.single, ['dart', 'run', 'bin/migrate.dart', 'fresh']);
    });
  });

  group('seed', () {
    test('delegates to db:seed', () async {
      expect(await run(['seed']), 0);
      expect(spawned.single, ['dart', 'run', 'bin/migrate.dart', 'db:seed']);
    });

    test('a generation failure stops before spawning anything', () async {
      File('${root.path}/lib/models/broken.dart').writeAsStringSync('''
import 'package:beak_core/beak_core.dart';

final class BrokenModel extends BeakModel {
  BrokenModel(this.table);
  @override
  final String table;
}
''');
      expect(await run(['seed']), 1);
      expect(spawned, isEmpty);
    });
  });
}
