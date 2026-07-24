part of 'beak_block.dart';

/// A data-bound profile page: one record's identity fields rendered on
/// `OiProfilePage`.
///
/// [nameField] is the headline; [roleField] is the subtitle; [avatarField]
/// (a URL) is the avatar; [emailField] and [bioField] fill the identity
/// card. `OiProfilePage` has no cover/banner slot, so none is exposed.
///
/// ```dart
/// BeakProfileBlock(
///   model: const UserModel(),
///   recordId: 'u-1',
///   nameField: UserColumns.name,
///   roleField: UserColumns.role,
///   avatarField: UserColumns.avatarUrl,
///   emailField: UserColumns.email,
///   bioField: UserColumns.bio,
/// );
/// ```
final class BeakProfileBlock extends BeakBlock {
  /// Creates a profile block for [recordId] of [model].
  const BeakProfileBlock({
    required this.model,
    required this.recordId,
    required this.nameField,
    this.emailField,
    this.roleField,
    this.avatarField,
    this.bioField,
    this.label = 'Profile',
    super.span,
  });

  /// The model the profile record belongs to.
  final BeakModel model;

  /// Primary key of the profile record.
  final Object recordId;

  /// Column supplying the display name.
  final BeakColumn nameField;

  /// Column supplying the email, when bound.
  final BeakColumn? emailField;

  /// Column supplying the role/subtitle, when bound.
  final BeakColumn? roleField;

  /// Column supplying the avatar URL, when bound.
  final BeakColumn? avatarField;

  /// Column supplying the bio, when bound.
  final BeakColumn? bioField;

  /// Accessibility label for the page.
  final String label;
}
