/// Bidirectional naming convention conversions.
library;

/// Pure-function naming utilities for converting
/// between camelCase, PascalCase, and snake_case.
///
/// All methods are static. This class cannot be
/// instantiated or subclassed.
final class NamingConvention {
  NamingConvention._();

  /// Converts a camelCase or PascalCase [input]
  /// to snake_case.
  ///
  /// Consecutive uppercase letters are treated as
  /// an acronym and kept together, with a boundary
  /// inserted before the last uppercase letter
  /// when followed by a lowercase letter.
  ///
  /// ```dart
  /// NamingConvention.toSnakeCase('userId');
  /// // => 'user_id'
  /// NamingConvention.toSnakeCase('HTMLContent');
  /// // => 'html_content'
  /// ```
  static String toSnakeCase(String input) {
    if (input.isEmpty) return '';

    final buffer = StringBuffer();
    final runes = input.runes.toList();

    for (var i = 0; i < runes.length; i++) {
      final char = String.fromCharCode(runes[i]);
      final isUpper = _isUpperCase(runes[i]);

      if (isUpper && i > 0) {
        final prevUpper = _isUpperCase(runes[i - 1]);
        final nextLower = i + 1 < runes.length && _isLowerCase(runes[i + 1]);

        if (!prevUpper || nextLower) {
          buffer.write('_');
        }
      }

      buffer.write(char.toLowerCase());
    }

    return buffer.toString();
  }

  /// Converts a snake_case [input] to camelCase.
  ///
  /// ```dart
  /// NamingConvention.toCamelCase('user_id');
  /// // => 'userId'
  /// ```
  static String toCamelCase(String input) {
    if (input.isEmpty) return '';

    final parts = input.split('_');
    final buffer = StringBuffer(parts.first);

    for (var i = 1; i < parts.length; i++) {
      final part = parts[i];
      if (part.isEmpty) continue;
      buffer
        ..write(part[0].toUpperCase())
        ..write(part.substring(1));
    }

    return buffer.toString();
  }

  /// Converts a PascalCase model name to a
  /// plural snake_case table name.
  ///
  /// ```dart
  /// NamingConvention.tableName('User');
  /// // => 'users'
  /// NamingConvention.tableName('BlogPost');
  /// // => 'blog_posts'
  /// ```
  static String tableName(String input) {
    if (input.isEmpty) return '';

    final snake = toSnakeCase(input);
    return _pluralize(snake);
  }

  /// Conventional pivot table name for a many-to-many between [a] and
  /// [b]: the singular snake_case of each class name, ordered
  /// alphabetically and joined with `_`.
  ///
  /// ```dart
  /// NamingConvention.pivotTableName('User', 'Role');
  /// // => 'role_user'
  /// ```
  static String pivotTableName(String a, String b) {
    final names = <String>[toSnakeCase(a), toSnakeCase(b)]..sort();
    return names.join('_');
  }

  /// Irregular singular → plural forms applied before the suffix
  /// rules in [_pluralizeWord].
  static const Map<String, String> _irregularPlurals = <String, String>{
    'person': 'people',
    'child': 'children',
    'man': 'men',
    'woman': 'women',
    'tooth': 'teeth',
    'foot': 'feet',
    'mouse': 'mice',
    'goose': 'geese',
    'index': 'indices',
    'matrix': 'matrices',
    'vertex': 'vertices',
  };

  /// Words whose plural equals their singular.
  static const Set<String> _uncountable = <String>{
    'data',
    'equipment',
    'information',
    'series',
    'species',
    'fish',
    'sheep',
    'deer',
  };

  /// Pluralizes only the final segment of a snake_case [word]
  /// (`blog_post` → `blog_posts`).
  static String _pluralize(String word) {
    if (word.isEmpty) return '';
    final underscore = word.lastIndexOf('_');
    if (underscore == -1) return _pluralizeWord(word);
    final head = word.substring(0, underscore + 1);
    final tail = word.substring(underscore + 1);
    return '$head${_pluralizeWord(tail)}';
  }

  static String _pluralizeWord(String word) {
    if (word.isEmpty) return '';
    if (_uncountable.contains(word)) return word;
    final irregular = _irregularPlurals[word];
    if (irregular != null) return irregular;
    // -y after a consonant → -ies (but -ay/-ey/-oy/-uy/-iy → +s).
    if (word.endsWith('y') &&
        word.length > 1 &&
        !_isVowel(word[word.length - 2])) {
      return '${word.substring(0, word.length - 1)}ies';
    }
    // Sibilant endings → -es.
    if (word.endsWith('s') ||
        word.endsWith('x') ||
        word.endsWith('z') ||
        word.endsWith('ch') ||
        word.endsWith('sh')) {
      return '${word}es';
    }
    // -fe / -f → -ves.
    if (word.endsWith('fe')) {
      return '${word.substring(0, word.length - 2)}ves';
    }
    if (word.endsWith('f')) {
      return '${word.substring(0, word.length - 1)}ves';
    }
    return '${word}s';
  }

  static bool _isVowel(String character) => 'aeiou'.contains(character);

  static bool _isUpperCase(int rune) => rune >= 0x41 && rune <= 0x5A;

  static bool _isLowerCase(int rune) => rune >= 0x61 && rune <= 0x7A;
}
