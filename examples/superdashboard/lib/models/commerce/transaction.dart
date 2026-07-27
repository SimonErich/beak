import 'package:beak_core/beak_core.dart';

import '../shared/enums.dart';
import '../shared/shared_columns.dart';

/// How a transaction was paid.
enum PaymentMethod {
  /// Credit or debit card.
  card,

  /// A PayPal account.
  paypal,

  /// A bank transfer.
  bankTransfer,

  /// A stored wallet balance.
  wallet,
}

/// The card network of a card transaction.
enum CardBrand {
  /// Visa.
  visa,

  /// Mastercard.
  mastercard,

  /// American Express.
  amex,

  /// PayPal.
  paypal,
}

/// Direction of money movement.
enum TxDirection {
  /// Money received.
  incoming,

  /// Money paid out.
  outgoing,
}

/// Typed columns of the transactions resource — feeds the dashboard
/// latest-transactions table.
abstract final class TransactionColumns {
  /// Human-readable reference.
  static const reference = BeakStringColumn(
    key: 'reference',
    label: 'Reference',
    searchable: true,
    rules: [BeakMaxLength(40)],
  );

  /// The paying/receiving user.
  static const userId = BeakStringColumn(
    key: 'user_id',
    label: 'User',
    visibleOn: {BeakContext.form},
  );

  /// The related order, if any.
  static const orderId = BeakStringColumn(
    key: 'order_id',
    label: 'Order',
    visibleOn: {BeakContext.form},
  );

  /// Payment method.
  static const method = BeakEnumColumn<PaymentMethod>(
    key: 'method',
    label: 'Method',
    values: PaymentMethod.values,
    defaultValue: PaymentMethod.card,
    filterable: true,
    badgeColors: {
      PaymentMethod.card: BeakColor.primary,
      PaymentMethod.paypal: BeakColor.info,
      PaymentMethod.bankTransfer: BeakColor.secondary,
      PaymentMethod.wallet: BeakColor.success,
    },
  );

  /// Card network.
  static const brand = BeakEnumColumn<CardBrand>(
    key: 'brand',
    label: 'Brand',
    values: CardBrand.values,
    defaultValue: CardBrand.visa,
    visibleOn: {BeakContext.form, BeakContext.detail},
    badgeColors: {
      CardBrand.visa: BeakColor.primary,
      CardBrand.mastercard: BeakColor.warning,
      CardBrand.amex: BeakColor.info,
      CardBrand.paypal: BeakColor.secondary,
    },
  );

  /// Transaction amount in dollars.
  static const amount = BeakDecimalColumn(
    key: 'amount',
    label: 'Amount',
    prefix: r'$',
    sortable: true,
  );

  /// Settlement state.
  static const status = BeakEnumColumn<PaymentStatus>(
    key: 'status',
    label: 'Status',
    values: PaymentStatus.values,
    defaultValue: PaymentStatus.paid,
    filterable: true,
    badgeColors: {
      PaymentStatus.pending: BeakColor.warning,
      PaymentStatus.paid: BeakColor.success,
      PaymentStatus.failed: BeakColor.error,
      PaymentStatus.refunded: BeakColor.muted,
    },
  );

  /// Money direction.
  static const direction = BeakEnumColumn<TxDirection>(
    key: 'direction',
    label: 'Direction',
    values: TxDirection.values,
    defaultValue: TxDirection.incoming,
    filterable: true,
    badgeColors: {
      TxDirection.incoming: BeakColor.success,
      TxDirection.outgoing: BeakColor.error,
    },
  );

  /// When the transaction occurred.
  static const occurredAt = BeakDateTimeColumn(
    key: 'occurred_at',
    label: 'When',
    format: BeakDateFormat.relative,
    sortable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    reference,
    userId,
    orderId,
    method,
    brand,
    amount,
    status,
    direction,
    occurredAt,
  ];
}

/// Typed relationships of the transactions resource.
abstract final class TransactionRelations {
  /// The paying/receiving user.
  static const user = BeakBelongsTo(
    key: 'user',
    label: 'User',
    relatedTable: 'users',
    displayColumnKey: 'name',
    foreignKey: 'user_id',
    searchColumnKeys: ['name', 'email'],
  );

  /// The related order, if any.
  static const order = BeakBelongsTo(
    key: 'order',
    label: 'Order',
    relatedTable: 'orders',
    displayColumnKey: 'reference',
    foreignKey: 'order_id',
    searchColumnKeys: ['reference'],
  );
}

/// The transactions resource — a single payment event.
final class TransactionModel extends BeakModel {
  /// Creates the transactions model.
  const TransactionModel();

  @override
  String get table => 'transactions';

  @override
  String get displayColumnKey => 'reference';

  @override
  List<BeakColumn> get columns => TransactionColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    TransactionRelations.user,
    TransactionRelations.order,
  ];
}
