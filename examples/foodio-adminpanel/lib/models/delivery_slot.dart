import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'delivery_slot.beak.dart';

/// DeliverySlot configuration shared by the panel and authoritative API.
@Resource(timestamps: true)
final class DeliverySlot extends BeakSchema {
  /// Name.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String name;

  /// Date.
  @Column(sortable: true, filterable: true)
  late final BeakDate date;

  /// Start minute.
  @Column(defaultValue: 0, rules: [BeakMin(0), BeakMax(1439)])
  late final int startMinute;

  /// End minute.
  @Column(defaultValue: 30, rules: [BeakMin(1), BeakMax(1440)])
  late final int endMinute;

  /// Capacity.
  @Column(defaultValue: 120, rules: [BeakMin(0)])
  late final int capacity;

  /// Reserved orders.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int reservedOrders;

  /// Route code.
  @Column(defaultValue: '')
  late final String? routeCode;

  /// Method.
  @Column(defaultValue: 'office')
  late final String method;

  /// Active.
  @Column(defaultValue: true)
  late final bool active;
}
