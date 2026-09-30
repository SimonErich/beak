import 'dart:io';

import 'package:path/path.dart' as p;

/// The settings a command reads from the environment, the way the server
/// reads them.
///
/// A project's `.env` supplies local defaults and the real process
/// environment wins over it, which is `BeakEnv.resolve()` in `beak_backend`.
/// The CLI reads the same two sources in the same order, so `beak doctor` and
/// `beak make:migration --from-drift` look at the database the server would
/// open, not at whichever of the two happens to be easier to read. It does not
/// depend on `beak_backend` for that: a scaffolding tool has no use for a
/// server.
abstract final class BeakDotenv {
  static final RegExp _key = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

  /// Parses dotenv [content] into key/value pairs.
  ///
  /// Supports comments, blank lines, an optional `export ` prefix, whitespace
  /// around `=`, and matching surrounding quotes, and splits on the first `=`
  /// only. A line that is not an assignment is skipped: the server refuses a
  /// malformed file when it boots, and a command asking for one setting has no
  /// reason to stop on another.
  static Map<String, String> parse(String content) {
    final entries = <String, String>{};
    for (final rawLine in content.split('\n')) {
      final String line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }
      final String assignment = line.startsWith('export ')
          ? line.substring('export '.length)
          : line;
      final int separator = assignment.indexOf('=');
      if (separator < 0) {
        continue;
      }
      final String key = assignment.substring(0, separator).trim();
      if (_key.hasMatch(key)) {
        entries[key] = _unquote(assignment.substring(separator + 1).trim());
      }
    }
    return entries;
  }

  /// The effective environment of the project at [root]: its `.env`, overlaid
  /// by [processEnvironment], so a real variable always beats a file value.
  static Map<String, String> resolve(
    Directory root, {
    required Map<String, String> processEnvironment,
  }) {
    final file = File(p.join(root.path, '.env'));
    return {
      if (file.existsSync()) ...parse(file.readAsStringSync()),
      ...processEnvironment,
    };
  }

  static String _unquote(String value) {
    for (final quote in const ['"', "'"]) {
      if (value.length >= 2 &&
          value.startsWith(quote) &&
          value.endsWith(quote)) {
        return value.substring(1, value.length - 1);
      }
    }
    return value;
  }
}
