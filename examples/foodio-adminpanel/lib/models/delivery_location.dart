import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'models.dart';

part 'delivery_location.beak.dart';

/// DeliveryLocation configuration shared by the panel and authoritative API.
@Resource(timestamps: true)
final class DeliveryLocation extends BeakSchema {
  /// Name.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String name;

  /// Organization.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final Organization? organization;

  /// Street.
  late final String street;

  /// Postal code.
  late final String postalCode;

  /// City.
  @Column(defaultValue: 'Wien')
  late final String city;

  /// Handover.
  @Column(defaultValue: '')
  late final String? handover;

  /// Route code.
  @Column(defaultValue: 'W4')
  late final String routeCode;

  /// Method.
  @Column(defaultValue: 'office')
  late final String method;

  /// Instructions.
  @Column(defaultValue: '')
  late final String? instructions;

  /// Active.
  @Column(defaultValue: true)
  late final bool active;
}
