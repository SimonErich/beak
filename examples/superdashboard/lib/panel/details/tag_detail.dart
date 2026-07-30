import 'package:beak/panel.dart';
import 'package:superdashboard/models/models.dart';

/// The tag show page: a headline card naming the label, followed by a card
/// listing every product that carries this tag.
const BeakBlock tagDetail = BeakColumnBlock(
  gapInPixels: 20,
  children: [
    BeakCardBlock(title: 'Tag', child: BeakFieldGroupBlock([TagColumns.name])),
    BeakCardBlock(
      title: 'Products',
      child: BeakRelationBlock(TagRelations.products),
    ),
  ],
);
