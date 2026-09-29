import 'dart:io';

import '../../support/beak_cli_internals.dart';
import 'package:test/test.dart';

/// What `beak init` records: the panel boots from a file of its own, and
/// `lib/main.dart` belongs to the app.
const String _beakYaml = '''
name: Acme Admin
panel:
  entrypoint: lib/admin_main.dart
''';

const String _pubspec =
    'name: acme_admin\ndependencies:\n  beak: ^0.9.0\n  flutter:\n    sdk: flutter\n';

const String _appMain = '''
import 'package:flutter/widgets.dart';

void main() => runApp(const SizedBox());
''';

const String _noteModel = '''
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

const String _noteResource = '''
import 'package:beak/panel.dart';

final class NoteResource extends BeakResource {
  const NoteResource() : super(model: const NoteModel());
}
''';

String _authoredEntrypoint(String resources) =>
    '''
import 'package:beak/panel.dart';
import 'package:flutter/widgets.dart';

import 'models/note.dart';
import 'note_resource.dart';

void main() => runApp(BeakPanel(title: 'Acme', resources: [$resources]));
''';

Directory _project(Map<String, String> files) {
  final root = Directory.systemTemp.createTempSync('beak_embedded_');
  addTearDown(() => root.deleteSync(recursive: true));
  for (final MapEntry(key: path, value: contents) in {
    'pubspec.yaml': _pubspec,
    'beak.yaml': _beakYaml,
    'lib/main.dart': _appMain,
    'lib/models/note.dart': _noteModel,
    ...files,
  }.entries) {
    final file = File('${root.path}/$path');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }
  return root;
}

BeakCliEnvironment _environmentFor(
  Directory root, {
  StringSink? out,
  BeakProcessRunner? runProcess,
}) => BeakCliEnvironment(
  out: out ?? StringBuffer(),
  rootDirectory: root,
  now: () => DateTime.utc(2026, 7, 26, 12),
  probe: (host, port) async => false,
  runProcess: runProcess,
);

Future<List<IntrospectedTable>> _neverRead(
  Uri url, {
  String schema = 'public',
}) async => throw StateError('a test read the live schema of $url');

void main() {
  group('beak prepare', () {
    test('never writes lib/main.dart, the app owns it', () {
      final root = _project({});

      final result = runPrepare(_environmentFor(root));

      expect(result.isSuccess, isTrue, reason: '${result.discovery.issues}');
      expect(result.written, isNot(contains('lib/main.dart')));
      expect(result.unchanged, isNot(contains('lib/main.dart')));
      expect(File('${root.path}/lib/main.dart').readAsStringSync(), _appMain);
    });

    test('still writes the wiring and the two bin entrypoints', () {
      final root = _project({});

      final result = runPrepare(_environmentFor(root));

      expect(
        result.written,
        containsAll([
          'lib/beak/registry.g.dart',
          'lib/beak/panel.g.dart',
          'lib/beak/app.g.dart',
          'lib/beak/server.g.dart',
          'bin/serve.dart',
          'bin/migrate.dart',
        ]),
      );
    });

    test('does not create lib/main.dart when there is none', () {
      final root = _project({});
      File('${root.path}/lib/main.dart').deleteSync();

      runPrepare(_environmentFor(root));

      expect(File('${root.path}/lib/main.dart').existsSync(), isFalse);
    });

    test('leaves a generated lib/main.dart of an earlier layout as it is', () {
      const generated = '${BeakEmitters.header}void main() {}\n';
      final root = _project({'lib/main.dart': generated});

      runPrepare(_environmentFor(root));

      expect(File('${root.path}/lib/main.dart').readAsStringSync(), generated);
    });

    test('reports the config it generated from', () {
      final result = runPrepare(_environmentFor(_project({})));

      expect(result.config.panel.entrypoint, 'lib/admin_main.dart');
    });

    test('a project that names no entrypoint still gets lib/main.dart', () {
      final root = _project({'beak.yaml': 'name: Acme Admin\n'});
      File('${root.path}/lib/main.dart').deleteSync();

      final result = runPrepare(_environmentFor(root));

      expect(result.written, contains('lib/main.dart'));
    });

    test('overwrites nothing at the entrypoint it is told about', () {
      final authored = _authoredEntrypoint('const NoteResource()');
      final root = _project({
        'lib/admin_main.dart': authored,
        'lib/note_resource.dart': _noteResource,
      });

      runPrepare(_environmentFor(root));

      expect(
        File('${root.path}/lib/admin_main.dart').readAsStringSync(),
        authored,
      );
    });
  });

  group('beak dev', () {
    test('prints the flutter run line for the entrypoint', () async {
      final root = _project({});
      final out = StringBuffer();

      final code = await createBeakRunner(
        _environmentFor(root, out: out),
      ).run(['dev', '--no-serve']);

      expect(code, 0);
      expect(
        out.toString(),
        contains('flutter run -d chrome -t lib/admin_main.dart'),
      );
    });

    test('keeps the device flag', () async {
      final out = StringBuffer();

      await createBeakRunner(
        _environmentFor(_project({}), out: out),
      ).run(['dev', '--no-serve', '-d', 'linux']);

      expect(
        out.toString(),
        contains('flutter run -d linux -t lib/admin_main.dart'),
      );
    });

    test('a project without an entrypoint prints the plain line', () async {
      final out = StringBuffer();

      await createBeakRunner(
        _environmentFor(_project({'beak.yaml': 'name: Acme\n'}), out: out),
      ).run(['dev', '--no-serve']);

      expect(out.toString(), contains('flutter run -d chrome\n'));
      expect(out.toString(), isNot(contains(' -t ')));
    });
  });

  group('beak doctor', () {
    Future<List<BeakCheck>> diagnoseIn(Directory root) =>
        diagnose(_environmentFor(root), readSchema: _neverRead);

    BeakCheck checkMatching(List<BeakCheck> checks, String needle) =>
        checks.firstWhere(
          (check) => check.label.contains(needle),
          orElse: () => throw StateError(
            'no check matching "$needle" in:\n'
            '${checks.map((check) => '  ${check.label}').join('\n')}',
          ),
        );

    test(
      'does not call a missing lib/main.dart a stale generated file',
      () async {
        final root = _project({});
        runPrepare(_environmentFor(root));
        File('${root.path}/lib/main.dart').deleteSync();

        final checks = await diagnoseIn(root);

        expect(
          checkMatching(checks, 'generated files up to date').status,
          BeakCheckStatus.ok,
        );
      },
    );

    test('follows the entrypoint, not lib/main.dart, for web safety', () async {
      // The app's own main may import whatever the app needs; only the panel
      // has to run in a browser.
      final root = _project({
        'lib/main.dart': "import 'package:beak/server.dart';\n$_appMain",
        'lib/admin_main.dart': _authoredEntrypoint(''),
      });
      runPrepare(_environmentFor(root));

      final checks = await diagnoseIn(root);

      expect(
        checkMatching(checks, 'no panel file imports the server').status,
        BeakCheckStatus.ok,
      );
    });

    test('fails a server import reachable from the entrypoint', () async {
      final root = _project({
        'lib/admin_main.dart': '''
import 'package:acme_admin/db.dart';
${_authoredEntrypoint('')}''',
        'lib/db.dart': "import 'package:beak/server.dart';\n",
      });
      runPrepare(_environmentFor(root));

      final check = checkMatching(await diagnoseIn(root), 'lib/db.dart');

      expect(check.status, BeakCheckStatus.fail);
      expect(check.label, contains('package:beak/server.dart'));
    });

    test('still walks lib/beak/app.g.dart from the generated wiring', () async {
      final root = _project({
        'lib/admin_main.dart': _authoredEntrypoint(''),
        'lib/screens/reports.dart': '''
import 'package:beak/panel.dart';
import 'package:beak/server.dart';

BeakScreen buildReportsScreen() => BeakScreen();
''',
      });
      runPrepare(_environmentFor(root));

      final check = checkMatching(
        await diagnoseIn(root),
        'lib/screens/reports.dart',
      );

      expect(check.status, BeakCheckStatus.fail);
    });

    test('a project whose entrypoint is not written yet reports the '
        'generated app only', () async {
      final root = _project({});
      runPrepare(_environmentFor(root));

      final checks = await diagnoseIn(root);

      expect(
        checkMatching(checks, 'no panel file imports the server').status,
        BeakCheckStatus.ok,
      );
    });

    test(
      'names the entrypoint when it does not list a resource class',
      () async {
        final root = _project({
          'lib/admin_main.dart': _authoredEntrypoint(''),
          'lib/note_resource.dart': _noteResource,
        });
        runPrepare(_environmentFor(root));

        final check = checkMatching(
          await diagnoseIn(root),
          'NoteResource (lib/note_resource.dart)',
        );

        expect(check.status, BeakCheckStatus.warn);
        expect(check.label, contains("lib/admin_main.dart's resources"));
        expect(check.remedy, contains('lib/admin_main.dart'));
      },
    );

    test('passes when the entrypoint lists every resource class', () async {
      final root = _project({
        'lib/admin_main.dart': _authoredEntrypoint('const NoteResource()'),
        'lib/note_resource.dart': _noteResource,
      });
      runPrepare(_environmentFor(root));

      final check = checkMatching(
        await diagnoseIn(root),
        'lib/admin_main.dart lists every resource class',
      );

      expect(check.status, BeakCheckStatus.ok);
    });

    test('the app\'s own lib/main.dart is not read as the panel', () async {
      // Reading it would report every resource as unlisted.
      final root = _project({
        'lib/admin_main.dart': _authoredEntrypoint('const NoteResource()'),
        'lib/note_resource.dart': _noteResource,
      });
      runPrepare(_environmentFor(root));

      final checks = await diagnoseIn(root);

      expect(
        checks.where((check) => check.label.contains('is not listed')),
        isEmpty,
      );
    });
  });

  group('beak make:resource', () {
    test('says where to register the class: the entrypoint', () async {
      final root = _project({
        'lib/admin_main.dart': _authoredEntrypoint('const NoteResource()'),
        'lib/note_resource.dart': _noteResource,
      });
      final out = StringBuffer();

      final code = await createBeakRunner(
        _environmentFor(root, out: out),
      ).run(['make:resource', 'Product']);

      expect(code, 0);
      expect(out.toString(), contains('lib/admin_main.dart is yours'));
      expect(
        out.toString(),
        contains("import 'resources/products/product_resource.dart';"),
      );
      expect(out.toString(), isNot(contains('lib/main.dart is yours')));
    });

    test(
      'prints nothing to register while the entrypoint is unwritten',
      () async {
        final out = StringBuffer();

        await createBeakRunner(
          _environmentFor(_project({}), out: out),
        ).run(['make:resource', 'Product']);

        expect(out.toString(), isNot(contains('is yours')));
      },
    );
  });
}
