import 'dart:io';

import 'package:test/test.dart';

import '../../support/beak_cli_internals.dart';

/// What a command says when the disk refuses it.
void main() {
  test('a directory it cannot write to ends in one line and exit 74, not a '
      'stack trace', () async {
    final root = Directory.systemTemp.createTempSync('beak_readonly_');
    addTearDown(() {
      Process.runSync('chmod', ['-R', 'u+w', root.path]);
      root.deleteSync(recursive: true);
    });
    File(
      '${root.path}/pubspec.yaml',
    ).writeAsStringSync('name: shop\ndependencies:\n  beak: any\n');
    Directory('${root.path}/lib').createSync();
    expect(Process.runSync('chmod', ['a-w', '${root.path}/lib']).exitCode, 0);
    final out = StringBuffer();

    final int? exitCode = await createBeakRunner(
      BeakCliEnvironment(
        out: out,
        rootDirectory: root,
        now: () => DateTime.utc(2026),
        probe: (host, port) async => false,
      ),
    ).run(['make:resource', 'Gadget']);

    expect(exitCode, 74);
    expect(out.toString(), contains('error:'));
    expect(out.toString(), contains('Permission denied'));
    expect(out.toString(), contains('${root.path}/lib'));
  });
}
