import 'package:beak/beak.dart';

import '../models/models.dart';

/// Transient command arguments; no table, migration or controller is needed.
final class RedeliveryInputModel extends BeakModel {
  /// Reuses normal validation and relation lookup in an action dialog.
  const RedeliveryInputModel();
  @override
  String get table => 'redelivery_input';
  @override
  String get displayColumnKey => 'delivery_date';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'ID'),
    BeakStringColumn(
      key: 'delivery_date',
      label: 'New delivery date',
      semantic: BeakSemantic.calendarDate(),
      rules: [BeakRequired()],
    ),
    BeakStringColumn(
      key: 'slot_id',
      label: 'Delivery slot',
      rules: [BeakRequired()],
    ),
  ];
  @override
  List<BeakRelationship> get relationships => [OrderRelations.slot];
  @override
  List<BeakRecordRule> get validationRules => [
    BeakExists(
      slotId,
      DeliverySlotModel.id,
      matching: [
        BeakFieldMatch(target: DeliverySlotModel.date, source: deliveryDate),
      ],
    ),
  ];

  /// Date selected by the operator, shared by server and action dialog.
  static const deliveryDate = BeakScalarField<BeakDate>(
    model: RedeliveryInputModel(),
    column: BeakStringColumn(
      key: 'delivery_date',
      label: 'Delivery date',
      semantic: BeakSemantic.calendarDate(),
    ),
  );

  /// The selected slot is validated against the selected calendar date.
  static const slotId = BeakScalarField<String>(
    model: RedeliveryInputModel(),
    column: BeakStringColumn(key: 'slot_id', label: 'Delivery slot'),
  );
}
