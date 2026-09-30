import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'models.dart';

part 'dish_option.beak.dart';

/// DishOption configuration shared by the panel and authoritative API.
@Resource(timestamps: true)
final class DishOption extends BeakSchema {
  /// Name.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String name;

  /// Dish.
  @BelongsTo(onDelete: BeakOnDelete.cascade)
  late final Dish dish;

  /// Price cents.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int priceCents;

  /// Allergens.
  @Column(defaultValue: '')
  late final String? allergens;

  /// Active.
  @Column(defaultValue: true)
  late final bool active;
}
