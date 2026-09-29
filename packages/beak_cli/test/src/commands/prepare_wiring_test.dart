import 'dart:io';

import 'package:test/test.dart';

import '../../support/beak_cli_internals.dart';
import 'prepare_command_test.dart'
    show environmentFor, noteModel, projectWith, read;

const String _authoredMain = '''
import 'package:beak/panel.dart';
import 'package:flutter/widgets.dart';

void main() => runApp(BeakPanel(title: 'Acme', resources: []));
''';

const String _embeddedYaml = 'panel:\n  entrypoint: lib/admin_main.dart\n';

const List<String> _wiring = ['lib/beak/panel.g.dart', 'lib/beak/app.g.dart'];

bool _exists(Directory root, String path) =>
    File('${root.path}/$path').existsSync();

void main() {
  group('a generated panel entrypoint', () {
    test('writes the panel config and the app widget', () {
      final root = projectWith({'lib/models/note.dart': noteModel});

      final result = runPrepare(environmentFor(root));

      expect(result.written, containsAll(_wiring));
    });
  });

  group('an authored lib/main.dart', () {
    test('gets no panel config or app widget nothing imports', () {
      final root = projectWith({
        'lib/models/note.dart': noteModel,
        'lib/main.dart': _authoredMain,
      });
      final out = StringBuffer();

      final result = runPrepare(environmentFor(root, out: out));

      expect(result.isSuccess, isTrue);
      for (final path in _wiring) {
        expect(result.written, isNot(contains(path)));
        expect(result.unchanged, isNot(contains(path)));
        expect(_exists(root, path), isFalse, reason: path);
      }
      expect(
        result.written,
        containsAll([
          'lib/beak/registry.g.dart',
          'lib/beak/server.g.dart',
          'bin/serve.dart',
          'bin/migrate.dart',
        ]),
      );
    });

    test('keeps them when a test imports the app widget', () {
      final root = projectWith({
        'lib/models/note.dart': noteModel,
        'lib/main.dart': _authoredMain,
        'test/app_test.dart':
            "import 'package:acme_admin/beak/app.g.dart';\nvoid main() {}\n",
      });

      final result = runPrepare(environmentFor(root));

      expect(result.written, containsAll(_wiring));
    });

    test('keeps them when another library imports the panel config', () {
      final root = projectWith({
        'lib/models/note.dart': noteModel,
        'lib/main.dart': _authoredMain,
        'lib/reports.dart': "import 'beak/panel.g.dart';\n",
      });

      final result = runPrepare(environmentFor(root));

      expect(result.written, contains('lib/beak/panel.g.dart'));
    });

    test('a name that only ends the same way does not count as an import', () {
      final root = projectWith({
        'lib/models/note.dart': noteModel,
        'lib/main.dart': _authoredMain,
        'lib/reports.dart': "import 'myapp.g.dart';\n",
      });

      final result = runPrepare(environmentFor(root));

      expect(result.written, isNot(contains('lib/beak/app.g.dart')));
    });
  });

  group('a panel with its own entrypoint', () {
    test('gets no panel config or app widget nothing imports', () {
      final root = projectWith({
        'lib/models/note.dart': noteModel,
        'beak.yaml': _embeddedYaml,
        'lib/admin_main.dart': _authoredMain,
      });

      final result = runPrepare(environmentFor(root));

      for (final path in _wiring) {
        expect(result.written, isNot(contains(path)));
        expect(_exists(root, path), isFalse, reason: path);
      }
    });

    test('still writes the wiring an entrypoint imports', () {
      final root = projectWith({
        'lib/models/note.dart': noteModel,
        'beak.yaml': _embeddedYaml,
        'lib/admin_main.dart':
            "import 'beak/app.g.dart';\nvoid main() => runApp(const BeakApp());\n",
      });

      final result = runPrepare(environmentFor(root));

      expect(result.written, containsAll(_wiring));
    });
  });

  group('wiring left over from a generated entrypoint', () {
    test('is removed once the entrypoint is authored, and says so', () {
      final root = projectWith({'lib/models/note.dart': noteModel});
      runPrepare(environmentFor(root));
      File('${root.path}/lib/main.dart').writeAsStringSync(_authoredMain);
      final out = StringBuffer();

      final result = runPrepare(environmentFor(root, out: out));

      expect(result.removed, _wiring);
      for (final path in _wiring) {
        expect(_exists(root, path), isFalse, reason: path);
      }
      expect(
        out.toString(),
        contains(
          'removed    lib/beak/panel.g.dart, lib/beak/app.g.dart: '
          'nothing imports them',
        ),
      );
    });

    test('is left alone when the file is not one Beak generated', () {
      final root = projectWith({
        'lib/models/note.dart': noteModel,
        'lib/main.dart': _authoredMain,
        'lib/beak/panel.g.dart': '// hand written\n',
      });

      final result = runPrepare(environmentFor(root));

      expect(result.removed, isEmpty);
      expect(read(root, 'lib/beak/panel.g.dart'), '// hand written\n');
    });
  });

  group('beak doctor', () {
    Future<List<BeakCheck>> diagnoseIn(Directory root) => diagnose(
      environmentFor(root),
      readSchema: (url, {String schema = 'public'}) async => const [],
    );

    test(
      'does not call the wiring an authored panel skips out of date',
      () async {
        final root = projectWith({
          'lib/models/note.dart': noteModel,
          'lib/main.dart': _authoredMain,
        });
        runPrepare(environmentFor(root));

        final checks = await diagnoseIn(root);

        final check = checks.firstWhere(
          (check) => check.label.contains('generated files'),
        );
        expect(check.label, 'generated files up to date');
      },
    );

    test('warns about wiring nothing imports any more', () async {
      final root = projectWith({'lib/models/note.dart': noteModel});
      runPrepare(environmentFor(root));
      File('${root.path}/lib/main.dart').writeAsStringSync(_authoredMain);

      final checks = await diagnoseIn(root);

      final check = checks.firstWhere(
        (check) => check.label.contains('nothing imports'),
      );
      expect(check.status, BeakCheckStatus.warn);
      expect(check.label, contains('lib/beak/panel.g.dart'));
      expect(check.label, contains('lib/beak/app.g.dart'));
      expect(check.remedy, 'beak prepare');
    });
  });
}
