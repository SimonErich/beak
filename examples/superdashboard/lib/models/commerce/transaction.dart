import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../people/user.dart';
import '../shared/enums.dart';
import 'order.dart';

part 'transaction.beak.dart';

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

/// The transactions resource — a single payment event.
@Resource()
final class Transaction extends BeakSchema {
  /// Human-readable reference.
  @Display()
  @Column(searchable: true, rules: [BeakMaxLength(40)])
  late final String? reference;

  /// The paying/receiving user.
  @BelongsTo(searchOn: ['name', 'email'])
  late final User? user;

  /// The related order, if any.
  @BelongsTo()
  late final Order? order;

  /// Payment method.
  @Column(defaultValue: PaymentMethod.card, filterable: true)
  @Badges({
    PaymentMethod.card: BeakColor.primary,
    PaymentMethod.paypal: BeakColor.info,
    PaymentMethod.bankTransfer: BeakColor.secondary,
    PaymentMethod.wallet: BeakColor.success,
  })
  late final PaymentMethod? method;

  /// Card network.
  @Column(
    defaultValue: CardBrand.visa,
    visibleOn: {BeakContext.form, BeakContext.detail},
  )
  @Badges({
    CardBrand.visa: BeakColor.primary,
    CardBrand.mastercard: BeakColor.warning,
    CardBrand.amex: BeakColor.info,
    CardBrand.paypal: BeakColor.secondary,
  })
  late final CardBrand? brand;

  /// Transaction amount in dollars.
  @Column(prefix: r'$', sortable: true)
  late final double? amount;

  /// Settlement state.
  @Column(defaultValue: PaymentStatus.paid, filterable: true)
  @Badges({
    PaymentStatus.pending: BeakColor.warning,
    PaymentStatus.paid: BeakColor.success,
    PaymentStatus.failed: BeakColor.error,
    PaymentStatus.refunded: BeakColor.muted,
  })
  late final PaymentStatus? status;

  /// Money direction.
  @Column(defaultValue: TxDirection.incoming, filterable: true)
  @Badges({
    TxDirection.incoming: BeakColor.success,
    TxDirection.outgoing: BeakColor.error,
  })
  late final TxDirection? direction;

  /// When the transaction occurred.
  @Column(label: 'When', format: BeakDateFormat.relative, sortable: true)
  late final DateTime? occurredAt;
}
