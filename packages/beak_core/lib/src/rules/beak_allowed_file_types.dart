part of 'beak_rule.dart';

/// Restricts an upload to [allowedTypes].
///
/// Validates [BeakFileType] values directly, and strings either as file
/// names (matched by extension, case-insensitively) or as exact MIME types.
/// An empty [allowedTypes] list allows everything.
///
/// ```dart
/// const rule = BeakAllowedFileTypes([BeakFileType.jpeg, BeakFileType.png]);
/// rule.validate('photo.PNG');       // null (extension matches)
/// rule.validate('image/jpeg');      // null (MIME matches)
/// rule.validate('notes.pdf');       // 'File type must be one of: jpg, png.'
/// ```
final class BeakAllowedFileTypes extends BeakRule {
  /// Creates a rule accepting only uploads of [allowedTypes].
  const BeakAllowedFileTypes(this.allowedTypes);

  /// The accepted file types; empty means unrestricted.
  final List<BeakFileType> allowedTypes;

  @override
  String get id => 'allowed_file_types';

  @override
  String? validate(Object? value) {
    if (allowedTypes.isEmpty) {
      return null;
    }
    final bool allowed = switch (value) {
      final BeakFileType type => allowedTypes.contains(type),
      final String nameOrMime => _matches(nameOrMime),
      _ => true,
    };
    if (allowed) {
      return null;
    }
    final String expected = allowedTypes
        .map((type) => type.extensions.first)
        .join(', ');
    return 'File type must be one of: $expected.';
  }

  bool _matches(String nameOrMime) {
    final String lower = nameOrMime.toLowerCase();
    return allowedTypes.any(
      (type) =>
          lower == type.mimeType ||
          type.extensions.any((extension) => lower.endsWith('.$extension')),
    );
  }
}
