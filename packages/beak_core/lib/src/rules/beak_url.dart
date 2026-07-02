part of 'beak_rule.dart';

/// Requires a string to be an absolute `http`/`https` URL with a host.
final class BeakUrl extends BeakRule {
  /// Creates the URL-format rule.
  const BeakUrl();

  @override
  String get id => 'url';

  @override
  String? validate(Object? value) => switch (value) {
    final String text when !_isHttpUrl(text) => 'Must be a valid URL.',
    _ => null,
  };

  static bool _isHttpUrl(String text) {
    final Uri? uri = Uri.tryParse(text);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }
}
