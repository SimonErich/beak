import 'dart:io';

import 'package:test/test.dart';

import '../../support/beak_cli_internals.dart';
import '../commands/doctor_command_test.dart' show checkMatching;
import '../commands/prepare_command_test.dart'
    show environmentFor, noteModel, projectWith, read;

const String _gabelYaml = 'theme:\n  preset: gabel\n';

const String _pubspecWithGabel =
    'name: acme_admin\ndependencies:\n  beak: any\n  beak_theme_gabel: any\n';

Directory _project({
  String beakYaml = _gabelYaml,
  String? pubspec = _pubspecWithGabel,
  Map<String, String> files = const {},
}) => projectWith({
  'pubspec.yaml': ?pubspec,
  'beak.yaml': beakYaml,
  'lib/models/note.dart': noteModel,
  ...files,
});

BeakProjectConfig _parse(String yaml) =>
    BeakProjectConfig.parse(yaml, packageName: 'acme_admin');

void main() {
  group('theme.preset in beak.yaml', () {
    test('is the standard theme when absent', () {
      expect(_parse('').themePreset, BeakThemePreset.standard);
      expect(
        _parse('theme:\n  sidebar:\n    collapsible: false\n').themePreset,
        BeakThemePreset.standard,
      );
    });

    test('names each allowed preset', () {
      expect(
        _parse('theme:\n  preset: standard\n').themePreset,
        BeakThemePreset.standard,
      );
      expect(_parse(_gabelYaml).themePreset, BeakThemePreset.gabel);
    });

    test('sits next to the sidebar settings', () {
      final config = _parse(
        'theme:\n  preset: gabel\n  sidebar:\n    startCollapsed: true\n',
      );

      expect(config.themePreset, BeakThemePreset.gabel);
      expect(config.sidebarStartCollapsed, isTrue);
    });

    test('an unknown preset lists the allowed ones', () {
      expect(
        () => _parse('theme:\n  preset: neon\n'),
        throwsA(
          isA<BeakProjectConfigException>().having(
            (error) => error.message,
            'message',
            'theme.preset must be one of: standard, gabel (got "neon").',
          ),
        ),
      );
    });

    test('an unknown theme key is still an error naming it', () {
      expect(
        () => _parse('theme:\n  colour: red\n'),
        throwsA(
          isA<BeakProjectConfigException>().having(
            (error) => error.message,
            'message',
            contains('theme.colour'),
          ),
        ),
      );
    });
  });

  group('the generated panel', () {
    test('selects GabelTheme and imports its package', () {
      final root = _project();

      final result = runPrepare(environmentFor(root));

      expect(result.isSuccess, isTrue);
      final panel = read(root, 'lib/beak/panel.g.dart');
      expect(
        panel,
        contains(
          "import 'package:beak_theme_gabel/beak_theme_gabel.dart' "
          'show GabelTheme;',
        ),
      );
      expect(panel, contains('theme: GabelTheme(),'));
    });

    test('names no theme under the standard preset', () {
      final root = _project(beakYaml: 'theme:\n  preset: standard\n');

      runPrepare(environmentFor(root));

      final panel = read(root, 'lib/beak/panel.g.dart');
      expect(panel, isNot(contains('theme:')));
      expect(panel, isNot(contains('beak_theme_gabel')));
    });

    test('is up to date for beak doctor after prepare', () async {
      final root = _project();
      runPrepare(environmentFor(root));

      final checks = await diagnose(environmentFor(root));

      expect(
        checkMatching(checks, 'generated files').status,
        BeakCheckStatus.ok,
      );
    });
  });

  group('the dependency', () {
    const missing = 'name: acme_admin\ndependencies:\n  beak: any\n';

    test('prepare refuses without beak_theme_gabel and says what to add', () {
      final root = _project(pubspec: missing);
      final out = StringBuffer();

      final result = runPrepare(environmentFor(root, out: out));

      expect(result.isSuccess, isFalse);
      expect(out.toString(), contains('theme.preset: gabel'));
      expect(out.toString(), contains('beak_theme_gabel'));
      expect(File('${root.path}/lib/beak/panel.g.dart').existsSync(), isFalse);
    });

    test('doctor fails and names the package', () async {
      final root = _project(pubspec: missing);

      final checks = await diagnose(environmentFor(root));

      final check = checkMatching(checks, 'beak_theme_gabel');
      expect(check.status, BeakCheckStatus.fail);
      expect(check.label, startsWith('pubspec.yaml:'));
    });

    test('is not asked of the standard preset', () {
      final root = _project(
        pubspec: missing,
        beakYaml: 'theme:\n  preset: standard\n',
      );

      expect(runPrepare(environmentFor(root)).isSuccess, isTrue);
    });
  });

  group('lib/theme.dart', () {
    final themeFile = EjectCommand.ejectedSource(BeakOverrideKind.theme);

    test('and a preset are two sources of one value: prepare refuses', () {
      final root = _project(files: {'lib/theme.dart': themeFile});
      final out = StringBuffer();

      final result = runPrepare(environmentFor(root, out: out));

      expect(result.isSuccess, isFalse);
      expect(out.toString(), contains('lib/theme.dart'));
      expect(out.toString(), contains('beakTheme()'));
    });

    test('declaring the old light and dark pair is refused, not ignored', () {
      final root = _project(
        beakYaml: '',
        files: {
          'lib/theme.dart': '''
import 'package:beak/ui.dart';

OiThemeData beakLightTheme() => OiThemeData.light();
OiThemeData beakDarkTheme() => OiThemeData.dark();
''',
        },
      );
      final out = StringBuffer();

      final result = runPrepare(environmentFor(root, out: out));

      expect(result.isSuccess, isFalse);
      expect(out.toString(), contains('lib/theme.dart'));
      expect(out.toString(), contains('BeakTheme beakTheme()'));
    });

    test('the old pair is a doctor failure too', () async {
      final root = _project(
        beakYaml: '',
        files: {'lib/theme.dart': 'void beakLightTheme() {}\n'},
      );

      final checks = await diagnose(environmentFor(root));

      expect(
        checkMatching(checks, 'beakLightTheme').status,
        BeakCheckStatus.fail,
      );
    });

    test('alone is wired as theme.beakTheme()', () {
      final root = _project(beakYaml: '', files: {'lib/theme.dart': themeFile});

      runPrepare(environmentFor(root));

      final panel = read(root, 'lib/beak/panel.g.dart');
      expect(panel, contains('theme: theme.beakTheme(),'));
      expect(panel, isNot(contains('darkTheme')));
    });
  });

  group('beak eject main', () {
    test('keeps the preset and drops const from the config', () async {
      final root = _project(
        beakYaml: '$_gabelYaml  sidebar:\n    startCollapsed: true\n',
        files: {
          'lib/main.dart':
              '// GENERATED BY beak prepare — DO NOT EDIT.\nvoid main() {}\n',
        },
      );
      final out = StringBuffer();

      final code = await createBeakRunner(
        environmentFor(root, out: out),
      ).run(['eject', 'main']);

      expect(code, 0, reason: '$out');
      final main = read(root, 'lib/main.dart');
      expect(main, contains('theme: GabelTheme()'));
      expect(main, contains('show GabelTheme;'));
      expect(main, isNot(contains('const BeakPanelConfig(')));
    });
  });

  group('beak init', () {
    test('names the package an existing preset needs', () async {
      final root = projectWith({
        'pubspec.yaml':
            'name: acme_admin\ndependencies:\n  flutter:\n    sdk: flutter\n',
        'lib/main.dart': 'void main() {}\n',
        'beak.yaml': _gabelYaml,
      });
      final out = StringBuffer();

      await createBeakRunner(
        environmentFor(root, out: out),
      ).run(['init', '--no-pub']);

      expect(out.toString(), contains('theme.preset: gabel'));
      expect(out.toString(), contains('add beak_theme_gabel to pubspec.yaml'));
    });
  });
}
