import 'package:test/test.dart';

import '../../support/beak_cli_internals.dart';
import 'prepare_command_test.dart'
    show environmentFor, noteModel, projectWith, read;

/// What `beak.yaml` says goes into generated Dart as a string, so a quote or a
/// dollar sign in it must arrive as text rather than as code.
void main() {
  test('a beak.yaml value with a quote or a dollar sign is escaped, not '
      'spliced into the generated source', () {
    final root = projectWith({
      'lib/models/note.dart': noteModel,
      'beak.yaml': '''
name: Acme
api:
  baseUrl: "https://admin.example.com/it's/\$api"
server:
  host: "it's"
''',
    });

    final result = runPrepare(environmentFor(root));

    expect(result.isSuccess, isTrue, reason: '${result.discovery.issues}');
    expect(read(root, 'lib/beak/server.g.dart'), contains(r"'HOST': 'it\'s'"));
    final String panel = read(root, 'lib/beak/panel.g.dart');
    expect(
      panel,
      contains(r"defaultValue: 'https://admin.example.com/it\'s/\$api'"),
    );
  });
}
