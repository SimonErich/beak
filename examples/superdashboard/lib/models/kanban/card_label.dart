import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'card.dart';

part 'card_label.beak.dart';

/// The card-labels resource — colored kanban tags.
@Resource()
final class CardLabel extends BeakSchema {
  /// Label name.
  @Display()
  @Column(searchable: true, rules: [BeakMaxLength(40)])
  late final String name;

  /// Label color.
  late final BeakHexColor? color;

  /// Cards carrying this label, via the `card_card_label` pivot.
  @BelongsToMany()
  late final List<Card> cards;
}
