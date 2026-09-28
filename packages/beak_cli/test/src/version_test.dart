import 'dart:io';

import 'package:beak_cli/beak_cli.dart';
import 'package:beak_cli/src/version.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('beakCliVersion is the version the pubspec declares', () {
    // The scaffold pins its Beak dependency to `v$beakCliVersion`, so a
    // constant that drifted from the pubspec would pin every new project to
    // a tag that describes a different CLI.
    final Object? pubspec = loadYaml(File('pubspec.yaml').readAsStringSync());
    expect(pubspec, isA<Map<Object?, Object?>>());
    if (pubspec case {'version': final Object? version}) {
      expect(version, beakCliVersion);
    } else {
      fail('pubspec.yaml declares no version');
    }
  });

  test('the pubspec puts `beak` on PATH when activated', () {
    final Object? pubspec = loadYaml(File('pubspec.yaml').readAsStringSync());
    expect(pubspec, containsPair('executables', {'beak': 'beak'}));
  });

  test('`beak --version` prints the version and exits 0', () async {
    final out = StringBuffer();
    final int? code = await createBeakRunner(
      BeakCliEnvironment(
        out: out,
        rootDirectory: Directory.systemTemp,
        now: () => DateTime.utc(2026),
        probe: (host, port) async => false,
      ),
    ).run(['--version']);

    expect(code, 0);
    expect(out.toString().trim(), 'beak $beakCliVersion');
  });
}
