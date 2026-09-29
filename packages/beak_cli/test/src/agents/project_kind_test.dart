import 'dart:io';

import 'package:beak_cli/src/agents/beak_block_renderer.dart';
import 'package:beak_cli/src/agents/beak_project_kind.dart';
import 'package:beak_cli/src/project/beak_project_config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('beak_kind_');
    addTearDown(() => root.deleteSync(recursive: true));
  });

  BeakProjectKind? detect(String pubspec, {String? beakYaml}) {
    File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync(pubspec);
    return BeakProjectKind.detect(
      root,
      config: beakYaml == null
          ? BeakProjectConfig.defaults(packageName: 'app')
          : BeakProjectConfig.parse(beakYaml, packageName: 'app'),
    );
  }

  String pubspec(
    List<String> dependencies, {
    String section = 'dependencies',
  }) =>
      'name: app\n$section:\n${[for (final d in dependencies) '  $d: any\n'].join()}';

  test('a Serverpod admin depends on beak_serverpod_flutter', () {
    expect(
      detect(pubspec(['beak', 'beak_serverpod_flutter'])),
      BeakProjectKind.serverpodAdmin,
    );
  });

  test('a Serverpod admin wins over an embedded entrypoint', () {
    expect(
      detect(
        pubspec(['beak_serverpod_flutter']),
        beakYaml: 'panel:\n  entrypoint: lib/admin_main.dart\n',
      ),
      BeakProjectKind.serverpodAdmin,
    );
  });

  test('an app with a panel entrypoint of its own is embedded', () {
    expect(
      detect(
        pubspec(['beak']),
        beakYaml: 'panel:\n  entrypoint: lib/admin_main.dart\n',
      ),
      BeakProjectKind.embedded,
    );
  });

  test('an entrypoint of lib/main.dart is standalone, not embedded', () {
    expect(
      detect(
        pubspec(['beak']),
        beakYaml: 'panel:\n  entrypoint: lib/main.dart\n',
      ),
      BeakProjectKind.standalone,
    );
  });

  test('a project that depends on beak is standalone', () {
    expect(detect(pubspec(['beak'])), BeakProjectKind.standalone);
  });

  test('so is one that depends on the parts', () {
    for (final part in [
      'beak_core',
      'beak_frontend',
      'beak_backend',
      'beak_serverpod',
    ]) {
      expect(detect(pubspec([part])), BeakProjectKind.standalone, reason: part);
    }
  });

  test('a dev dependency counts', () {
    expect(
      detect(pubspec(['beak'], section: 'dev_dependencies')),
      BeakProjectKind.standalone,
    );
  });

  test('a project without a Beak dependency has no kind', () {
    expect(detect(pubspec(['flutter', 'beak_test'])), isNull);
    expect(
      detect(
        pubspec(['flutter']),
        beakYaml: 'panel:\n  entrypoint: lib/admin_main.dart\n',
      ),
      isNull,
    );
  });

  test('a missing or unreadable pubspec has no kind', () {
    expect(
      BeakProjectKind.detect(
        root,
        config: BeakProjectConfig.defaults(packageName: 'app'),
      ),
      isNull,
    );
    expect(detect('a: [unclosed\n'), isNull);
    expect(detect('- a\n'), isNull);
  });

  test('each kind names its block template', () {
    expect(BeakProjectKind.standalone.block, BeakBlockKind.standalone);
    expect(BeakProjectKind.embedded.block, BeakBlockKind.embedded);
    expect(BeakProjectKind.serverpodAdmin.block, BeakBlockKind.serverpodAdmin);
  });

  test('the message for a project without Beak names the fix', () {
    expect(
      BeakProjectKind.notABeakProject,
      'no Beak dependency here; run `beak init`',
    );
  });
}
