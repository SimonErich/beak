import 'dart:convert';
import 'dart:io';

import 'package:beak_cli/src/agents/beak_docs_bundle.dart';
import 'package:beak_cli/src/agents/beak_workspace.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late Directory project;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('beak_docs_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    project = Directory(p.join(tmp.path, 'app'))..createSync();
    File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync('name: app\n');
  });

  BeakWorkspace workspace() => BeakWorkspace.locate(project);

  /// Writes a bundle of [pages] into beak_core's `doc/agent-docs`.
  ///
  /// [tamper] changes a file after the manifest was computed, so its hash no
  /// longer matches.
  Directory bundle({
    String version = '0.9.0',
    Map<String, String> pages = const {
      'ai-index.md': '# Index\n',
      'models/defining-models.md': '# Models\n',
    },
    Map<String, String> tamper = const {},
    int? pageCount,
  }) {
    final Directory root = Directory(p.join(tmp.path, 'pkgs', 'beak_core'))
      ..createSync(recursive: true);
    final Directory docs = Directory(p.join(root.path, 'doc', 'agent-docs'));
    if (docs.existsSync()) {
      docs.deleteSync(recursive: true);
    }
    final manifest = jsonEncode({
      'format': 1,
      'beak': version,
      'index': 'ai-index.md',
      'pages': pageCount ?? pages.length,
      'files': {
        for (final page in pages.entries)
          page.key: sha256.convert(utf8.encode(page.value)).toString(),
      },
    });
    for (final page in {...pages, ...tamper}.entries) {
      File(p.join(docs.path, page.key))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(page.value);
    }
    File(p.join(docs.path, 'manifest.json')).writeAsStringSync(manifest);
    return root;
  }

  /// Writes `pub get`'s resolution of beak_core to [root].
  void resolve(Directory root) {
    File(p.join(project.path, '.dart_tool', 'package_config.json'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {'name': 'beak_core', 'rootUri': root.uri.toString()},
          ],
        }),
      );
  }

  BeakDocsReady ready(BeakDocsResult result) => switch (result) {
    BeakDocsReady() => result,
    BeakDocsUnavailable(:final reason) => fail('unavailable: $reason'),
  };

  String unavailable(BeakDocsResult result) => switch (result) {
    BeakDocsUnavailable(:final reason) => reason,
    BeakDocsReady() => fail('expected the docs to be unavailable'),
  };

  Directory target() => workspace().docsDirectory;

  test('copies the bundle into .dart_tool/beak/docs', () {
    resolve(bundle());
    final BeakDocsReady result = ready(materializeDocs(workspace()));

    expect(result.status, BeakDocsStatus.written);
    expect(result.version, '0.9.0');
    expect(result.pages, 2);
    expect(result.directory.path, target().path);
    expect(result.indexFile.path, p.join(target().path, 'ai-index.md'));
    expect(
      File(
        p.join(target().path, 'models/defining-models.md'),
      ).readAsStringSync(),
      '# Models\n',
    );
    expect(File(p.join(target().path, 'manifest.json')).existsSync(), isTrue);
    expect(
      Directory(
        p.join(project.path, '.dart_tool', 'beak', 'docs.tmp'),
      ).existsSync(),
      isFalse,
    );
  });

  test('a second run finds the copy current and writes nothing', () {
    resolve(bundle());
    materializeDocs(workspace());
    final File index = File(p.join(target().path, 'ai-index.md'));
    final DateTime before = index.lastModifiedSync();
    index.setLastModifiedSync(before.subtract(const Duration(hours: 1)));
    final DateTime marked = index.lastModifiedSync();

    final BeakDocsReady again = ready(materializeDocs(workspace()));

    expect(again.status, BeakDocsStatus.unchanged);
    expect(index.lastModifiedSync(), marked);
  });

  test('a new version replaces the copy and removes files it dropped', () {
    resolve(bundle());
    materializeDocs(workspace());
    resolve(
      bundle(
        version: '0.9.1',
        pages: {'ai-index.md': '# Index 2\n', 'panel/tables.md': '# Tables\n'},
      ),
    );

    final BeakDocsReady result = ready(materializeDocs(workspace()));

    expect(result.status, BeakDocsStatus.written);
    expect(result.version, '0.9.1');
    expect(
      File(p.join(target().path, 'models/defining-models.md')).existsSync(),
      isFalse,
    );
    expect(
      File(p.join(target().path, 'panel/tables.md')).readAsStringSync(),
      '# Tables\n',
    );
  });

  test('a dry run reports what would be written and writes nothing', () {
    resolve(bundle());

    final BeakDocsReady result = ready(
      materializeDocs(workspace(), dryRun: true),
    );

    expect(result.status, BeakDocsStatus.pending);
    expect(result.version, '0.9.0');
    expect(target().existsSync(), isFalse);
    expect(
      Directory(p.join(project.path, '.dart_tool', 'beak')).existsSync(),
      isFalse,
    );
  });

  test('a dry run on a current copy reports it unchanged', () {
    resolve(bundle());
    materializeDocs(workspace());

    expect(
      ready(materializeDocs(workspace(), dryRun: true)).status,
      BeakDocsStatus.unchanged,
    );
  });

  test('no package config is unavailable, and says to run pub get', () {
    expect(
      unavailable(materializeDocs(workspace())),
      allOf(contains('package_config.json'), contains('flutter pub get')),
    );
    expect(target().existsSync(), isFalse);
  });

  test('a package config without beak_core is unavailable', () {
    File(p.join(project.path, '.dart_tool', 'package_config.json'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode({'configVersion': 2, 'packages': <Object?>[]}),
      );

    expect(
      unavailable(materializeDocs(workspace())),
      allOf(contains('beak_core'), contains('flutter pub get')),
    );
  });

  test('a beak_core with no bundle is unavailable', () {
    final Directory root = Directory(p.join(tmp.path, 'pkgs', 'beak_core'))
      ..createSync(recursive: true);
    File(
      p.join(root.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: beak_core\nversion: 0.8.0\n');
    resolve(root);

    expect(
      unavailable(materializeDocs(workspace())),
      allOf(contains('0.8.0'), contains('agent-docs')),
    );
  });

  test('a manifest that is not JSON is unavailable', () {
    final Directory root = bundle();
    File(
      p.join(root.path, 'doc', 'agent-docs', 'manifest.json'),
    ).writeAsStringSync('not json');
    resolve(root);

    expect(unavailable(materializeDocs(workspace())), contains('manifest'));
  });

  test('a manifest without files is unavailable', () {
    final Directory root = bundle();
    File(
      p.join(root.path, 'doc', 'agent-docs', 'manifest.json'),
    ).writeAsStringSync('{"beak": "0.9.0"}');
    resolve(root);

    expect(unavailable(materializeDocs(workspace())), contains('manifest'));
  });

  test('a file that fails its checksum is refused, keeping the old copy', () {
    resolve(bundle());
    materializeDocs(workspace());
    resolve(
      bundle(
        version: '0.9.1',
        pages: {'ai-index.md': '# Index 2\n'},
        tamper: {'ai-index.md': '# Not what was hashed\n'},
      ),
    );

    expect(
      unavailable(materializeDocs(workspace())),
      allOf(contains('ai-index.md'), contains('checksum')),
    );
    expect(
      File(p.join(target().path, 'ai-index.md')).readAsStringSync(),
      '# Index\n',
    );
    expect(
      Directory(
        p.join(project.path, '.dart_tool', 'beak', 'docs.tmp'),
      ).existsSync(),
      isFalse,
    );
  });

  test('a file the manifest lists but the bundle lacks is refused', () {
    final Directory root = bundle();
    File(p.join(root.path, 'doc', 'agent-docs', 'ai-index.md')).deleteSync();
    resolve(root);

    expect(unavailable(materializeDocs(workspace())), contains('ai-index.md'));
  });

  test('a manifest path that climbs out of the bundle is refused', () {
    final Directory root = bundle();
    File(
      p.join(root.path, 'doc', 'agent-docs', 'manifest.json'),
    ).writeAsStringSync(
      jsonEncode({
        'beak': '0.9.0',
        'files': {'../../escape.md': 'abc'},
      }),
    );
    resolve(root);

    expect(unavailable(materializeDocs(workspace())), contains('escape'));
    expect(File(p.join(tmp.path, 'pkgs', 'escape.md')).existsSync(), isFalse);
  });

  test('writes nothing outside .dart_tool/beak/docs', () {
    resolve(bundle());
    Set<String> tree() => {
      for (final entity in project.listSync(recursive: true))
        p.relative(entity.path, from: project.path),
    };
    final Set<String> before = tree();

    materializeDocs(workspace());

    final Set<String> added = tree().difference(before);
    expect(
      added.every(
        (path) =>
            p.isWithin(p.join('.dart_tool', 'beak'), path) ||
            path == p.join('.dart_tool', 'beak'),
      ),
      isTrue,
      reason: '$added',
    );
  });

  test('the docs of a workspace member land in the workspace root', () {
    final Directory root = bundle();
    File(
      p.join(tmp.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: root\nworkspace:\n  - app\n');
    File(
      p.join(project.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: app\nresolution: workspace\n');
    File(p.join(tmp.path, '.dart_tool', 'package_config.json'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {'name': 'beak_core', 'rootUri': root.uri.toString()},
          ],
        }),
      );

    final BeakDocsReady result = ready(materializeDocs(workspace()));

    expect(
      result.directory.path,
      p.join(tmp.path, '.dart_tool', 'beak', 'docs'),
    );
  });

  test('a bundle it cannot write is unavailable, not an exception', () {
    resolve(bundle());
    // A file where the directory must go.
    File(
      p.join(project.path, '.dart_tool', 'beak'),
    ).writeAsStringSync('in the way');

    expect(unavailable(materializeDocs(workspace())), contains('could not'));
  });
}
