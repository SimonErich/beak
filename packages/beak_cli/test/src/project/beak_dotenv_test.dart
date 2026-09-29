import 'dart:io';

import 'package:test/test.dart';

import '../../support/beak_cli_internals.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('beak_dotenv_');
    addTearDown(() => root.deleteSync(recursive: true));
  });

  void writeEnv(String content) =>
      File('${root.path}/.env').writeAsStringSync(content);

  group('BeakDotenv.parse', () {
    test('reads what the server reads: comments, export, quotes, spaces', () {
      expect(
        BeakDotenv.parse('''
# a comment
PORT=8080
export HOST = 0.0.0.0
DATABASE_URL="postgres://u:p@localhost/db"
NAME='beak'
EMPTY=
'''),
        {
          'PORT': '8080',
          'HOST': '0.0.0.0',
          'DATABASE_URL': 'postgres://u:p@localhost/db',
          'NAME': 'beak',
          'EMPTY': '',
        },
      );
    });

    test('splits on the first = only', () {
      expect(BeakDotenv.parse('URL=a=b=c\n'), {'URL': 'a=b=c'});
    });

    test('skips a line it cannot read rather than stopping the command', () {
      // The server refuses a malformed .env at boot. A command that only
      // wants one setting should still get the others.
      expect(BeakDotenv.parse('nonsense\n9BAD=1\nGOOD=1\n'), {'GOOD': '1'});
    });
  });

  group('BeakDotenv.resolve', () {
    test('is the .env under the process environment', () {
      writeEnv('DATABASE_URL=sqlite:from_file.db\nWORM_ENV=production\n');

      expect(
        BeakDotenv.resolve(
          root,
          processEnvironment: {'DATABASE_URL': 'sqlite:from_shell.db'},
        ),
        {'DATABASE_URL': 'sqlite:from_shell.db', 'WORM_ENV': 'production'},
      );
    });

    test('is the process environment alone when there is no .env', () {
      expect(BeakDotenv.resolve(root, processEnvironment: {'PORT': '9000'}), {
        'PORT': '9000',
      });
    });
  });
}
