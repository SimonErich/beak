part of 'beak_rule.dart';

/// Requires a string to look like an email address
/// (`local@domain.tld`, no whitespace, at most 254 characters).
///
/// The shape is checked without a backtracking pattern: validation runs on the
/// server's only isolate, and a hostile value must not be able to occupy it.
final class BeakEmail extends BeakRule {
  /// Creates the email-format rule.
  // --8<-- [start:BeakEmail]
  const BeakEmail();
  // --8<-- [end:BeakEmail]

  static const int _maxLengthInCharacters = 254;
  static final RegExp _whitespace = RegExp(r'\s');

  // One `@` with something before it, and in the domain a dot that has a
  // character on each side.
  static bool _looksLikeAddress(String text) {
    if (text.length > _maxLengthInCharacters || text.contains(_whitespace)) {
      return false;
    }
    final int at = text.indexOf('@');
    if (at < 1 || at != text.lastIndexOf('@')) return false;
    final String domain = text.substring(at + 1);
    final int dot = domain.indexOf('.', 1);
    return dot != -1 && dot < domain.length - 1;
  }

  @override
  String get id => 'email';

  @override
  String? validate(Object? value) => switch (value) {
    final String text when !_looksLikeAddress(text) =>
      'Must be a valid email address.',
    _ => null,
  };
}
