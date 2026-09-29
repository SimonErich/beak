/// The English plurals a table name is most likely to need, singular first.
///
/// Small on purpose: the generator names a table it cannot ask about, and
/// `@Resource(table:)` is the answer for anything this misses.
const Map<String, String> _irregularPlurals = {
  'person': 'people',
  'man': 'men',
  'woman': 'women',
  'child': 'children',
  'foot': 'feet',
  'tooth': 'teeth',
  'mouse': 'mice',
  'goose': 'geese',
  'ox': 'oxen',
  'quiz': 'quizzes',
};

/// Words whose plural is the word itself.
const Set<String> _invariantWords = {
  'sheep',
  'fish',
  'deer',
  'series',
  'species',
  'equipment',
  'information',
  'news',
  'staff',
  'media',
};

/// The reverse of [_irregularPlurals].
final Map<String, String> _irregularSingulars = {
  for (final entry in _irregularPlurals.entries) entry.value: entry.key,
};

/// The last word of a snake_case or UpperCamelCase name.
final RegExp _lastWord = RegExp('[A-Z]?[a-z]+\$');

/// `category` -> `categories`, `box` -> `boxes`, `person` -> `people`.
///
/// The one pluraliser: a table name and the migration class naming it must
/// agree, and appending a bare `s` gave `CreateCategorysTable` beside a
/// `categories` table. Only the last word of a compound name is inflected,
/// and its capitalisation is kept.
///
/// The rules are the regular ones plus a short table of irregular and
/// invariant words: `s`, `x`, `z`, `ch` and `sh` take `es`, a consonant and
/// `y` become `ies`, a vowel and `y` keep the `y`, and everything else takes
/// `s`. Anything else that pluralises irregularly is named with
/// `@Resource(table:)`.
///
/// ```dart
/// pluralOf('Category'); // 'Categories'
/// pluralOf('Key');      // 'Keys'
/// pluralOf('person');   // 'people'
/// pluralOf('product');  // 'products'
/// ```
String pluralOf(String word) => _inflectLastWord(word, _pluralWord);

/// The inverse of [pluralOf], for the names derived from a table.
///
/// `people` -> `person`, `categories` -> `category`, `order_items` ->
/// `order_item`. A word that ends in `ss`, `us` or `is` is already singular
/// (`status`, `address`, `analysis`) and is returned as it is.
///
/// ```dart
/// singularOf('order_items'); // 'order_item'
/// singularOf('people');      // 'person'
/// ```
String singularOf(String word) => _inflectLastWord(word, _singularWord);

String _inflectLastWord(String word, String Function(String) inflect) {
  final Match? match = _lastWord.firstMatch(word);
  if (match == null) {
    return inflect(word);
  }
  return '${word.substring(0, match.start)}${inflect(match.group(0)!)}';
}

String _pluralWord(String word) {
  final String lower = word.toLowerCase();
  if (_invariantWords.contains(lower)) {
    return word;
  }
  if (_irregularPlurals[lower] case final String plural) {
    return _withCaseOf(word, plural);
  }
  if (RegExp('(s|x|z|ch|sh)\$').hasMatch(lower)) {
    return '${word}es';
  }
  if (lower.endsWith('y') && !_endsInVowelAndY(lower)) {
    return '${word.substring(0, word.length - 1)}ies';
  }
  return '${word}s';
}

String _singularWord(String word) {
  final String lower = word.toLowerCase();
  if (_invariantWords.contains(lower)) {
    return word;
  }
  if (_irregularSingulars[lower] case final String singular) {
    return _withCaseOf(word, singular);
  }
  if (lower.endsWith('ies')) {
    return '${word.substring(0, word.length - 3)}y';
  }
  if (RegExp('(s|x|ch|sh)es\$').hasMatch(lower)) {
    return word.substring(0, word.length - 2);
  }
  // `status`, `address`, `class` and friends end in `s` but are already
  // singular; stripping it produces `statu`, which nobody would type.
  if (lower.endsWith('ss') || lower.endsWith('us') || lower.endsWith('is')) {
    return word;
  }
  return lower.endsWith('s') ? word.substring(0, word.length - 1) : word;
}

/// Whether [lower] ends in a vowel followed by `y` (`day`, `key`, `boy`).
bool _endsInVowelAndY(String lower) =>
    lower.length > 1 && 'aeiou'.contains(lower[lower.length - 2]);

/// [replacement], capitalised when [original] is.
String _withCaseOf(String original, String replacement) =>
    original[0] == original[0].toUpperCase() &&
        original[0] != original[0].toLowerCase()
    ? '${replacement[0].toUpperCase()}${replacement.substring(1)}'
    : replacement;
