/// The character that escapes `%`, `_` and itself in the pattern of a `like`
/// or `ilike` filter (and in the patterns Beak builds for substring
/// operators and searches).
///
/// A data source states it explicitly, so `50\%` means the text `50%` on every
/// database rather than depending on the database's default escape character
/// (SQLite has none, PostgreSQL and MySQL default to a backslash).
const String beakLikeEscape = r'\';

/// [text] as a `LIKE` operand that matches exactly [text]: every `%`, `_` and
/// escape character in it is escaped with [beakLikeEscape].
///
/// Build a substring pattern with it, `'%${beakEscapeLike(term)}%'`, so a
/// user searching for `50%` does not match every row that contains `50`.
String beakEscapeLike(String text) => text.replaceAllMapped(
  RegExp(r'[\\%_]'),
  (match) => '$beakLikeEscape${match[0]}',
);

/// A regular expression matching exactly the text a `LIKE` [pattern] matches:
/// `%` is any run of characters (newlines included), `_` is any one character,
/// and [beakLikeEscape] makes the character after it literal. A trailing
/// escape character stands for itself.
///
/// For data sources that evaluate a pattern in Dart (a test double, a
/// key-value store) instead of asking a database. Matching is
/// case-sensitive unless [caseSensitive] is `false`, which is what `ilike`
/// means.
RegExp beakLikeRegExp(String pattern, {bool caseSensitive = true}) {
  final source = StringBuffer('^');
  final characters = pattern.split('');
  for (var index = 0; index < characters.length; index++) {
    final character = characters[index];
    if (character == beakLikeEscape) {
      source.write(
        RegExp.escape(
          index + 1 < characters.length ? characters[++index] : character,
        ),
      );
    } else if (character == '%') {
      source.write('.*');
    } else if (character == '_') {
      source.write('.');
    } else {
      source.write(RegExp.escape(character));
    }
  }
  source.write(r'$');
  return RegExp(source.toString(), caseSensitive: caseSensitive, dotAll: true);
}
