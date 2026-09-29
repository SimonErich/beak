import 'dart:convert';
import 'dart:io';

import 'package:beak_cli/src/agents/beak_package_config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('beak_package_config_');
    addTearDown(() => tmp.deleteSync(recursive: true));
  });

  /// A `package_config.json` in `<tmp>/app/.dart_tool` listing [packages].
  File config(List<Map<String, Object?>> packages) {
    final file =
        File(p.join(tmp.path, 'app', '.dart_tool', 'package_config.json'))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(
            jsonEncode({'configVersion': 2, 'packages': packages}),
          );
    return file;
  }

  Directory package(String path, {String? version}) {
    final directory = Directory(p.join(tmp.path, path))
      ..createSync(recursive: true);
    if (version != null) {
      File(
        p.join(directory.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: ${p.basename(path)}\nversion: $version\n');
    }
    return directory;
  }

  group('BeakPackageConfig.read', () {
    test('keeps beak and beak_* packages, and nothing else', () {
      final Directory beak = package('packages/beak', version: '0.9.0');
      final Directory core = package('packages/beak_core', version: '0.9.0');
      package('packages/other', version: '1.0.0');
      final BeakPackageConfig? read = BeakPackageConfig.read(
        config([
          {'name': 'beak', 'rootUri': '../../packages/beak'},
          {'name': 'beak_core', 'rootUri': '../../packages/beak_core'},
          {'name': 'other', 'rootUri': '../../packages/other'},
          {'name': 'beakon', 'rootUri': '../../packages/other'},
        ]),
      );

      expect(read!.packages.keys, ['beak', 'beak_core']);
      expect(read.packages['beak']!.root.path, beak.path);
      expect(read.packages['beak_core']!.root.path, core.path);
      expect(read.umbrella!.version, '0.9.0');
      expect(read.core!.name, 'beak_core');
    });

    test('resolves a relative rootUri against the .dart_tool folder', () {
      final Directory core = package('vendored/core', version: '1.2.3');
      final BeakPackageConfig read = BeakPackageConfig.read(
        config([
          {'name': 'beak_core', 'rootUri': '../../vendored/core'},
        ]),
      )!;

      expect(read.core!.root.path, core.path);
      expect(read.core!.version, '1.2.3');
    });

    test('resolves an absolute file URI, as a git or hosted cache has', () {
      final Directory git = package(
        'cache/git/beak-abc123/packages/beak_core',
        version: '0.9.0',
      );
      final Directory hosted = package(
        'cache/hosted/pub.dev/beak-0.9.0',
        version: '0.9.0',
      );
      final BeakPackageConfig read = BeakPackageConfig.read(
        config([
          {'name': 'beak_core', 'rootUri': git.uri.toString()},
          {'name': 'beak', 'rootUri': hosted.uri.toString()},
        ]),
      )!;

      expect(read.core!.root.path, git.path);
      expect(read.umbrella!.root.path, hosted.path);
    });

    test('a package without a pubspec has no version', () {
      package('packages/beak_core');
      final BeakPackageConfig read = BeakPackageConfig.read(
        config([
          {'name': 'beak_core', 'rootUri': '../../packages/beak_core'},
        ]),
      )!;

      expect(read.core!.version, isNull);
    });

    test('a pubspec without a version has no version', () {
      package('packages/beak_core', version: '1.0.0');
      File(
        p.join(tmp.path, 'packages/beak_core/pubspec.yaml'),
      ).writeAsStringSync('name: beak_core\n');

      expect(
        BeakPackageConfig.read(
          config([
            {'name': 'beak_core', 'rootUri': '../../packages/beak_core'},
          ]),
        )!.core!.version,
        isNull,
      );
    });

    test('a pubspec that is not YAML has no version', () {
      package('packages/beak_core', version: '1.0.0');
      File(
        p.join(tmp.path, 'packages/beak_core/pubspec.yaml'),
      ).writeAsStringSync('a: [unclosed\n');

      expect(
        BeakPackageConfig.read(
          config([
            {'name': 'beak_core', 'rootUri': '../../packages/beak_core'},
          ]),
        )!.core!.version,
        isNull,
      );
    });

    test('skips entries that are not name and rootUri strings', () {
      package('packages/beak_core', version: '0.9.0');
      final BeakPackageConfig read = BeakPackageConfig.read(
        config([
          {'name': 'beak_core', 'rootUri': '../../packages/beak_core'},
          {'name': 7, 'rootUri': '../x'},
          {'name': 'beak_bad'},
          {'name': 'beak_remote', 'rootUri': 'https://example.com/x'},
        ]),
      )!;

      expect(read.packages.keys, ['beak_core']);
    });

    test('resolves against the file even when the path given is relative', () {
      final Directory core = package('packages/beak_core', version: '0.9.0');
      final File file = config([
        {'name': 'beak_core', 'rootUri': '../../packages/beak_core'},
      ]);
      final String relative = p.relative(file.path);

      final BeakPackageConfig? read = BeakPackageConfig.read(File(relative));

      expect(read!.core!.root.path, core.path);
    });

    test('is null for a missing file', () {
      expect(
        BeakPackageConfig.read(File(p.join(tmp.path, 'nothing.json'))),
        isNull,
      );
    });

    test('is null for a file that is not a package config', () {
      for (final content in ['not json', '[]', '{}', '{"packages": 3}']) {
        final file = File(p.join(tmp.path, 'bad.json'))
          ..writeAsStringSync(content);

        expect(BeakPackageConfig.read(file), isNull, reason: content);
      }
    });
  });

  group('BeakPackageConfig.rootPathOf', () {
    final Uri base = Uri.parse('file:///home/me/app/.dart_tool/');

    test('a relative reference climbs out of .dart_tool', () {
      expect(
        BeakPackageConfig.rootPathOf('../../packages/beak', base: base),
        '/home/me/packages/beak',
      );
    });

    test('a git cache URI is used as written', () {
      expect(
        BeakPackageConfig.rootPathOf(
          'file:///home/me/.pub-cache/git/beak-1f2e3d/packages/beak_core',
          base: base,
        ),
        '/home/me/.pub-cache/git/beak-1f2e3d/packages/beak_core',
      );
    });

    test('a hosted URI is used as written, without a trailing slash', () {
      expect(
        BeakPackageConfig.rootPathOf(
          'file:///home/me/.pub-cache/hosted/pub.dev/beak-0.9.0/',
          base: base,
        ),
        '/home/me/.pub-cache/hosted/pub.dev/beak-0.9.0',
      );
    });

    test('a Windows drive URI becomes a drive path', () {
      expect(
        BeakPackageConfig.rootPathOf(
          'file:///C:/Users/me/AppData/Local/Pub/Cache/hosted/pub.dev/beak-0.9.0',
          base: Uri.parse('file:///C:/proj/app/.dart_tool/'),
          windows: true,
        ),
        r'C:\Users\me\AppData\Local\Pub\Cache\hosted\pub.dev\beak-0.9.0',
      );
    });

    test('a Windows relative reference resolves on the same drive', () {
      expect(
        BeakPackageConfig.rootPathOf(
          '../../shared/beak',
          base: Uri.parse('file:///C:/proj/app/.dart_tool/'),
          windows: true,
        ),
        r'C:\proj\shared\beak',
      );
    });

    test('a URI that is not a file has no path', () {
      expect(
        BeakPackageConfig.rootPathOf('https://example.com/x', base: base),
        isNull,
      );
    });
  });
}
