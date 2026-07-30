/// Zero-cost authoring types, so a field's declared type selects its column.
///
/// `String` alone cannot say whether a field is a single-line name, a
/// multi-line body, rich text, a colour, or a stored file — and encoding that
/// as a `kind:` parameter on an annotation would be a stringly-typed
/// discriminator, which is the exact hole Beak's typed columns close. These
/// extension types carry the distinction in the type system instead, and
/// compile away to the `String` they wrap.
///
/// ```dart
/// late final String title;        // BeakStringColumn
/// late final BeakText body;       // BeakTextColumn
/// late final BeakRichText notes;  // BeakRichTextColumn
/// late final BeakHexColor tint;   // BeakColorColumn
/// late final BeakImageRef? cover; // BeakImageColumn
/// ```
library;

/// A multi-line plain-text value — the authoring type behind a
/// `BeakTextColumn`.
extension type const BeakText(String value) implements String {}

/// A rich-text (HTML or Markdown) value — the authoring type behind a
/// `BeakRichTextColumn`.
extension type const BeakRichText(String value) implements String {}

/// A `#rrggbb` colour — the authoring type behind a `BeakColorColumn`.
extension type const BeakHexColor(String hex) implements String {}

/// A stored image, addressed by its storage key — the authoring type behind
/// a `BeakImageColumn`.
extension type const BeakImageRef(String storageKey) implements String {}

/// A stored file, addressed by its storage key — the authoring type behind a
/// `BeakFileColumn`.
extension type const BeakFileRef(String storageKey) implements String {}
