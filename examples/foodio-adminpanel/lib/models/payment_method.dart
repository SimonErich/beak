import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'models.dart';

part 'payment_method.beak.dart';

/// PaymentMethod configuration shared by the panel and authoritative API.
@Resource(timestamps: true)
final class PaymentMethod extends BeakSchema {
  /// Name.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String name;

  /// Customer.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final Customer customer;

  /// Kind.
  @Column(defaultValue: 'card')
  late final String kind;

  /// Last four.
  @Column(defaultValue: '4242')
  late final String lastFour;

  /// Provider token.
  @Column(defaultValue: 'demo_visa_4242')
  late final String providerToken;

  /// Demo outcome.
  @Column(defaultValue: 'succeeded')
  late final String demoOutcome;

  /// Is default.
  @Column(defaultValue: true)
  late final bool isDefault;

  /// Active.
  @Column(defaultValue: true)
  late final bool active;
}
