import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'fulfillment_policy.beak.dart';

/// Reusable dispatch and delivery terms for a shop's fulfillment team.
@Resource()
final class FulfillmentPolicy extends BeakSchema {
  /// Friendly policy title.
  @Display()
  @Column(searchable: true, rules: [BeakMaxLength(120)])
  late final String name;

  /// Stable unique URL-safe identifier.
  @Column(semantic: BeakSemantic.slug(), unique: true, searchable: true)
  late final String code;

  /// Address receiving carrier or fulfillment questions.
  @Column(semantic: BeakSemantic.email())
  late final String? supportEmail;

  /// Contact number in international or national notation.
  @Column(semantic: BeakSemantic.phone())
  late final String? supportPhone;

  /// Public tracking/help URL.
  @Column(semantic: BeakSemantic.url())
  late final String? trackingUrl;

  /// ISO currency used by this policy, independent of the panel locale.
  @Column(
    defaultValue: 'EUR',
    rules: [
      BeakInList(['EUR', 'USD', 'GBP']),
    ],
  )
  late final String currency;

  /// Exact amount stored in minor units, never binary floating point.
  @Column(
    semantic: BeakSemantic.money(scale: 2),
    currencyFrom: #currency,
    defaultValue: BeakDecimal(490, scale: 2),
  )
  late final BeakDecimal deliveryFee;

  /// Fractional insurance markup; 0.025 means 2.5%.
  @Column(
    semantic: BeakSemantic.percentage(scale: 1),
    precision: 4,
    defaultValue: 0.025,
    rules: [BeakMin(0), BeakMax(1)],
  )
  late final double insuranceRate;

  /// Maximum shipment weight in kilograms.
  @Column(
    semantic: BeakSemantic.quantity(unit: 'kg'),
    rules: [BeakMin(0)],
  )
  late final double? maximumWeight;

  /// Maximum accepted attachment length in bytes.
  @Column(
    semantic: BeakSemantic.fileSize(),
    rules: [BeakMin(0)],
    defaultValue: 10485760,
  )
  late final int attachmentLimit;

  /// First business day to apply this policy; never shifts with timezone.
  late final BeakDate? effectiveDate;

  /// Local warehouse dispatch cutoff, independent of calendar date.
  late final BeakTime? dispatchCutoff;

  /// Handling duration before dispatch.
  @Column(defaultValue: Duration(hours: 24))
  late final Duration handlingTime;

  /// Optional promotional validity interval, stored as UTC instants.
  late final DateTime? promotionStartsAt;

  /// End of the optional promotional validity interval.
  late final DateTime? promotionEndsAt;

  /// Operational labels edited as a typed string list.
  @Column(defaultValue: <String>[])
  late final List<String> tags;

  /// Allowed delivery regions, edited with a checkbox group.
  @Column(defaultValue: <String>['AT', 'DE'])
  late final List<String> regions;

  /// Null delegates signature requirements to the carrier's default.
  late final bool? signatureRequired;

  /// Delivery speed used by routing teams.
  @Column(defaultValue: DeliverySpeed.standard)
  late final DeliverySpeed speed;

  /// Structured origin address reusing normal field semantics and rules.
  @Column(semantic: BeakSemantic.object(DispatchAddress.schema))
  late final BeakJsonObject? origin;

  /// Optional provider-specific structured JSON configuration.
  late final BeakJson? providerOptions;

  /// Conditions shared by local validation and authoritative API writes.
  static List<BeakRecordRule> get validationRules => [
    BeakAfterField(
      FulfillmentPolicyModel.promotionEndsAt,
      FulfillmentPolicyModel.promotionStartsAt,
      inclusive: true,
    ),
    BeakRequiredIf(
      FulfillmentPolicyModel.promotionEndsAt,
      when: BeakWhen.present(FulfillmentPolicyModel.promotionStartsAt),
    ),
  ];
}

/// Fulfillment speeds used by radio and filter choices.
enum DeliverySpeed {
  /// Ordinary warehouse processing.
  standard,

  /// Priority processing.
  express,

  /// Customer pickup from the warehouse.
  pickup,
}

/// A typed embedded object; no independent CRUD resource is needed.
abstract final class DispatchAddress {
  /// Street and house number.
  static const street = BeakStringColumn(
    key: 'street',
    label: 'Street',
    rules: [BeakRequired()],
    maxLength: 160,
  );

  /// Postal identifier, retaining leading zeroes.
  static const postalCode = BeakStringColumn(
    key: 'postal_code',
    label: 'Postal code',
    rules: [BeakRequired()],
    maxLength: 12,
  );

  /// City or town.
  static const city = BeakStringColumn(
    key: 'city',
    label: 'City',
    rules: [BeakRequired()],
    maxLength: 100,
  );

  /// Contact email with the same rules as a resource field.
  static const email = BeakStringColumn(
    key: 'email',
    label: 'Contact email',
    semantic: BeakSemantic.email(),
  );

  /// Reusable structure for forms, validation and storage.
  static const schema = BeakObjectSchema(
    columns: [street, postalCode, city, email],
  );
}
