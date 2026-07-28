import 'dart:io';

import 'package:beak_core/beak_core.dart';

/// Dotenv-style environment loading for the Beak backend.
///
/// A `.env` file provides local development defaults; the real process
/// environment always wins so deployments configure themselves without a
/// file. Secrets never live in committed files (`.env` is git-ignored, a
/// committed `.env.example` documents the keys).
abstract final class BeakEnv {
  static final RegExp _keyPattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

  /// Parses dotenv [content] into key/value pairs.
  ///
  /// Supports comments (`#`), blank lines, an optional `export ` prefix,
  /// whitespace around the `=` separator, and matching surrounding quotes.
  /// Splits on the first `=` only. Throws a [BeakConfigurationException] on
  /// a line without a separator or with an invalid key.
  static Map<String, String> parse(String content) {
    final entries = <String, String>{};
    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }
      final unexported = line.startsWith('export ')
          ? line.substring('export '.length)
          : line;
      final separatorIndex = unexported.indexOf('=');
      if (separatorIndex < 0) {
        throw BeakConfigurationException(
          'Malformed dotenv line (no "=" separator): "$rawLine".',
        );
      }
      final key = unexported.substring(0, separatorIndex).trim();
      if (!_keyPattern.hasMatch(key)) {
        throw BeakConfigurationException(
          'Malformed dotenv key "$key" in line "$rawLine".',
        );
      }
      entries[key] = _unquote(unexported.substring(separatorIndex + 1).trim());
    }
    return entries;
  }

  /// Parses the dotenv file at [path], returning an empty map when the file
  /// does not exist (a `.env` is optional in every environment).
  static Map<String, String> loadFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return const {};
    }
    return parse(file.readAsStringSync());
  }

  /// The effective environment: the dotenv file at [filePath] overlaid by
  /// [processEnvironment] (defaults to [Platform.environment]), so real
  /// environment variables always win over file values.
  ///
  /// Feed the result straight into [BeakBackendConfig.fromEnv]:
  ///
  /// ```dart
  /// final config = BeakBackendConfig.fromEnv(
  ///   environment: BeakEnv.resolve(),
  /// );
  /// ```
  // --8<-- [start:resolve]
  static Map<String, String> resolve({
    String filePath = '.env',
    Map<String, String>? processEnvironment,
  }) => {...loadFile(filePath), ...processEnvironment ?? Platform.environment};
  // --8<-- [end:resolve]

  static String _unquote(String value) {
    const quotes = ['"', "'"];
    for (final quote in quotes) {
      if (value.length >= 2 &&
          value.startsWith(quote) &&
          value.endsWith(quote)) {
        return value.substring(1, value.length - 1);
      }
    }
    return value;
  }
}
