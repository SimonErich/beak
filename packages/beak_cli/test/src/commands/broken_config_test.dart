import 'dart:io';

import '../../support/beak_cli_internals.dart';
import 'package:test/test.dart';

/// A `beak.yaml` that is not YAML must stop every command that reads it with
/// a message naming the file, the line and the column, not a scanner stack
/// trace. `beak.yaml` is optional but a broken one is not the same as absent.
void main() {
  late Directory root;
  late StringBuffer out;

  setUp(() {
    root = Directory.systemTemp.createTempSync('beak_broken_config_');
    addTearDown(() => root.deleteSync(recursive: true));
    out = StringBuffer();
    File(
      '${root.path}/pubspec.yaml',
    ).writeAsStringSync('name: shop\ndependencies:\n  beak: any\n');
    File('${root.path}/beak.yaml').writeAsStringSync('name: Shop\nlist: [a\n');
  });

  BeakCliEnvironment environment() => BeakCliEnvironment(
    out: out,
    rootDirectory: root,
    now: () => DateTime.utc(2026),
    probe: (host, port) async => false,
  );

  Future<int> run(List<String> args) async =>
      await createBeakRunner(environment()).run(args) ?? 0;

  Matcher namesTheSyntaxError() =>
      allOf(contains('beak.yaml'), contains('line 3'), contains('column 1'));

  test('`beak prepare` reports it and writes nothing', () async {
    expect(await run(['prepare']), 1);

    expect(out.toString(), namesTheSyntaxError());
    expect(Directory('${root.path}/lib').existsSync(), isFalse);
  });

  test('`beak eject main` reports it and leaves lib/main.dart alone', () async {
    expect(await run(['eject', 'main']), 1);

    expect(out.toString(), namesTheSyntaxError());
    expect(File('${root.path}/lib/main.dart').existsSync(), isFalse);
  });

  test('`beak eject resource` reports it', () async {
    File('${root.path}/lib/models/note.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
import 'package:beak/beak.dart';

final class NoteModel extends BeakModel {
  const NoteModel();

  @override
  String get table => 'notes';
}
''');

    expect(await run(['eject', 'resource', 'notes']), 1);

    expect(out.toString(), namesTheSyntaxError());
  });

  test('`beak doctor` fails with it, and stops there', () async {
    expect(await run(['doctor']), 1);

    expect(out.toString(), contains('FAIL'));
    expect(out.toString(), namesTheSyntaxError());
  });

  test('a config that is merely unknown is reported the same way', () async {
    File('${root.path}/beak.yaml').writeAsStringSync('colour: blue\n');

    expect(await run(['prepare']), 1);
    expect(out.toString(), contains('colour'));
  });
}
