import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'models.dart';

part 'dish.beak.dart';

/// Dish configuration shared by the panel and authoritative API.
@Resource(table: 'dishes', timestamps: true)
final class Dish extends BeakSchema {
  /// Name.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String name;

  /// Description.
  @Column(defaultValue: '')
  late final String? description;

  /// Category.
  @Column(defaultValue: 'Mains')
  late final String category;

  /// Allergens.
  @Column(defaultValue: '')
  late final String? allergens;

  /// Diet.
  @Column(defaultValue: '')
  late final String? diet;

  /// Image key.
  @Column(defaultValue: '')
  late final String? imageKey;

  /// Tax basis points.
  @Column(defaultValue: 1000, rules: [BeakMin(0)])
  late final int taxBasisPoints;

  /// Food.
  @Column(defaultValue: true)
  late final bool food;

  /// Active.
  @Column(defaultValue: true)
  late final bool active;

  /// Variants.
  @HasMany(owned: true, onDelete: BeakOnDelete.cascade)
  late final List<DishVariant> variants;

  /// Options.
  @HasMany(owned: true, onDelete: BeakOnDelete.cascade)
  late final List<DishOption> options;
}
