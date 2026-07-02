/// The ORM- and UI-neutral rendering hint a column resolves to for a given
/// `BeakContext`.
///
/// `beak_core` never imports Flutter: a column only declares *what* should be
/// rendered (a badge, a thumbnail, a relative date, ...) and `beak_frontend`
/// maps each intent to the matching obers_ui widget.
enum BeakRenderIntent {
  /// Plain single-line text.
  text,

  /// A numeric value with locale-aware formatting.
  number,

  /// A monetary amount with currency prefix/suffix formatting.
  currency,

  /// A colored badge/chip, typically for enum or status values.
  badge,

  /// A full-size image rendered from a stored file.
  image,

  /// A small preview image, typically inside table cells.
  thumbnail,

  /// A boolean rendered as a toggle, checkmark, or yes/no badge.
  boolean,

  /// An absolute date or timestamp.
  date,

  /// A humanized relative timestamp such as "3 days ago".
  relativeDate,

  /// A link to a single related record (belongs-to style relations).
  relationLink,

  /// A badge list of related records (many-to-many style relations).
  relationBadges,

  /// Formatted rich text (rendered markup, not raw source).
  richText,

  /// A color swatch for color-valued columns.
  color,

  /// Pretty-printed structured JSON data.
  json,

  /// A user-provided custom renderer (the escape hatch).
  custom,
}
