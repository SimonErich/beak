import 'package:beak/beak.dart';

/// The typed payload every order effect carries through the outbox.
///
/// Not a table: it only names the fields of the persisted effect record, so
/// the code that enqueues an effect and the provider that delivers it read and
/// write the same typed fields.
final class FoodioEffectPayloadModel extends BeakModel {
  /// Describes the payload record, which has no storage of its own.
  const FoodioEffectPayloadModel();

  /// The order the effect concerns.
  static const orderId = BeakScalarField<String>(
    model: FoodioEffectPayloadModel(),
    column: _Columns.orderId,
  );

  /// The order's gross amount when the effect was queued, in cents.
  static const amountInCents = BeakScalarField<int>(
    model: FoodioEffectPayloadModel(),
    column: _Columns.amountInCents,
  );

  /// The order's public reference when the effect was queued.
  static const reference = BeakScalarField<String>(
    model: FoodioEffectPayloadModel(),
    column: _Columns.reference,
  );

  /// Who receives a message effect.
  static const recipient = BeakScalarField<String>(
    model: FoodioEffectPayloadModel(),
    column: _Columns.recipient,
  );

  /// The saved payment method a charge uses.
  static const paymentMethodId = BeakScalarField<String>(
    model: FoodioEffectPayloadModel(),
    column: _Columns.paymentMethodId,
  );

  /// The payment mode when the effect was queued.
  static const paymentMode = BeakScalarField<String>(
    model: FoodioEffectPayloadModel(),
    column: _Columns.paymentMode,
  );

  @override
  String get table => 'foodio_effect_payload';

  @override
  String get displayColumnKey => 'order_id';

  @override
  List<BeakColumn> get columns => _Columns.values;
}

abstract final class _Columns {
  static const orderId = BeakStringColumn(key: 'order_id', label: 'Order');
  static const amountInCents = BeakIntColumn(
    key: 'amount_cents',
    label: 'Amount',
  );
  static const reference = BeakStringColumn(
    key: 'reference',
    label: 'Reference',
  );
  static const recipient = BeakStringColumn(
    key: 'recipient',
    label: 'Recipient',
  );
  static const paymentMethodId = BeakStringColumn(
    key: 'payment_method_id',
    label: 'Payment method',
  );
  static const paymentMode = BeakStringColumn(
    key: 'payment_mode',
    label: 'Payment mode',
  );
  static const values = <BeakColumn>[
    orderId,
    amountInCents,
    reference,
    recipient,
    paymentMethodId,
    paymentMode,
  ];
}
