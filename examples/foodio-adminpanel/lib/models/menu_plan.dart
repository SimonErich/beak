import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'models.dart';

part 'menu_plan.beak.dart';

/// MenuPlan configuration shared by the panel and authoritative API.
@Resource(timestamps: true)
final class MenuPlan extends BeakSchema {
  /// Name.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String name;

  /// Description.
  @Column(defaultValue: '')
  late final String? description;

  /// Active.
  @Column(defaultValue: true)
  late final bool active;

  /// Items.
  @HasMany(owned: true, onDelete: BeakOnDelete.cascade)
  late final List<MenuPlanItem> items;
}
