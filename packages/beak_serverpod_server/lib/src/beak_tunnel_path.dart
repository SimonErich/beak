/// The internal URL a tunnelled request is served under, or `null` when
/// [path] must not reach Beak.
///
/// Every segment is percent-decoded before it is judged, and anything that
/// could steer the router somewhere else is refused rather than resolved:
/// empty segments (`//`), dot segments (`.`, `..`, `%2e%2e`), and segments
/// that decode to a separator or a control character. What is left must be
/// under `/api/`, and never Beak's own login surface (`/api/auth/**`):
/// Serverpod owns sign-in. Health probes and file routes live outside `/api`
/// and are refused as well.
Uri? beakTunnelUrl(String path, String query) {
  if (!path.startsWith('/') || path.length > 2048 || query.length > 8192) {
    return null;
  }
  final segments = <String>[];
  for (final raw in path.substring(1).split('/')) {
    final String segment;
    try {
      segment = Uri.decodeComponent(raw);
    } on ArgumentError {
      return null;
    } on FormatException {
      return null;
    }
    if (segment.isEmpty ||
        segment == '.' ||
        segment == '..' ||
        segment.contains('/') ||
        segment.contains(r'\') ||
        segment.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f)) {
      return null;
    }
    segments.add(segment);
  }
  // --8<-- [start:apiOnly]
  if (segments.length < 2 || segments.first != 'api' || segments[1] == 'auth') {
    return null;
  }
  // --8<-- [end:apiOnly]
  final Uri url;
  try {
    url = Uri(
      scheme: 'http',
      host: 'beak.internal',
      pathSegments: segments,
      query: query.isEmpty ? null : query,
    );
  } on FormatException {
    return null;
  }
  return url;
}
