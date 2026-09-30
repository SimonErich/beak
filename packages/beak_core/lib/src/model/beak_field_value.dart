import 'package:meta/meta.dart';

import '../data/beak_commit.dart';
import '../query/beak_value.dart';
import 'beak_field_ref.dart';

/// A typed root field paired with the value it should hold.
///
/// Create one with [BeakScalarField.to]. It carries the encoded value, so
/// writing code lists fields and values and never a storage key:
///
/// ```dart
/// final record = const OrderNoteModel().record([
///   OrderNoteModel.body.to('Call the customer'),
///   OrderNoteModel.visibility.to('internal'),
/// ]);
/// ```
@immutable
final class BeakFieldValue {
  /// Pairs [field] with its already encoded [value].
  ///
  /// Prefer [BeakScalarField.to], which encodes the typed value.
  const BeakFieldValue(this.field, this.value);

  /// The field receiving the value.
  final BeakScalarField<Object> field;

  /// The canonical storage representation of the value.
  final BeakValue value;
}

/// A typed belongs-to field paired with the record it should point at.
///
/// Create one with [BeakToOneField.linkTo]. A save operation turns it into the
/// foreign-key reference, resolving a draft target when the plan runs.
@immutable
final class BeakFieldLink {
  /// Pairs [field] with [target], which must be a record of the related model.
  const BeakFieldLink(this.field, this.target);

  /// The belongs-to field being pointed at [target].
  final BeakToOneField field;

  /// The existing or draft record the field references.
  final BeakRecordRef target;
}
