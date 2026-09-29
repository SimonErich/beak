import 'package:beak/beak.dart';

// --8<-- [start:FoodioNoteInput]
/// Transient arguments shared by the Add note dialog and API validation.
final class OrderNoteInputModel extends BeakModel {
  /// Requires a bounded, nonempty note without exposing audit metadata.
  const OrderNoteInputModel({this.required = true});

  /// Edit submissions may omit a note; direct Add note always requires one.
  final bool required;

  /// Typed placement used by the inline editor.
  static const body = BeakScalarField<String>(
    model: OrderNoteInputModel(),
    column: BeakStringColumn(
      key: 'body',
      label: 'New internal note',
      rules: [BeakRequired(), BeakMaxLength(2000)],
    ),
  );

  @override
  String get table => 'order_note_input';

  @override
  String get displayColumnKey => 'body';

  @override
  List<BeakColumn> get columns => [
    const BeakStringColumn(key: 'id', label: 'ID'),
    BeakStringColumn(
      key: 'body',
      label: 'Internal note',
      rules: [if (required) const BeakRequired(), const BeakMaxLength(2000)],
    ),
  ];
}
// --8<-- [end:FoodioNoteInput]
