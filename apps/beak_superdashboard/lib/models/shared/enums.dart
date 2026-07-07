/// Enumerations shared across two or more domains. Domain-specific enums
/// (e.g. `ProductStatus`) live in their owning model file instead.
library;

/// A person's presence indicator, reused by users and chat participants.
enum OnlineStatus {
  /// Actively online.
  online,

  /// Online but idle.
  away,

  /// Online but do-not-disturb.
  busy,

  /// Not online.
  offline,
}

/// Work priority, reused by kanban cards and tasks.
enum Priority {
  /// Lowest urgency.
  low,

  /// Normal urgency.
  medium,

  /// Elevated urgency.
  high,

  /// Highest urgency.
  urgent,
}

/// Settlement state of a payable, reused by orders, transactions, invoices.
enum PaymentStatus {
  /// Awaiting settlement.
  pending,

  /// Settled in full.
  paid,

  /// Settlement failed.
  failed,

  /// Reversed after settlement.
  refunded,
}

/// Where a purchase originated, reused by orders and the analytics
/// source-of-purchases breakdown.
enum PurchaseSource {
  /// A direct visit.
  direct,

  /// A social-media referral.
  social,

  /// An email-campaign referral.
  email,

  /// An affiliate referral.
  affiliate,

  /// An organic-search referral.
  search,
}

/// The kind of a stored attachment, reused by email, chat, files, and users.
enum AttachmentKind {
  /// A raster or vector image.
  image,

  /// A generic document.
  document,

  /// A PDF document.
  pdf,

  /// A video clip.
  video,

  /// An audio clip.
  audio,

  /// A compressed archive.
  archive,

  /// A spreadsheet.
  spreadsheet,

  /// A source-code file.
  code,
}
