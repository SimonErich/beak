import 'package:beak_frontend/beak_frontend.dart';
import 'package:superdashboard/models/models.dart';

/// The category show page: a headline card naming the category, followed by an
/// inline table of every product filed under it.
const BeakBlock categoryDetail = BeakColumnBlock(
  gapInPixels: 20,
  children: [
    BeakCardBlock(
      title: 'Category',
      child: BeakFieldGroupBlock([CategoryColumns.name], columnCount: 2),
    ),
    BeakCardBlock(
      title: 'Products',
      child: BeakRelationBlock(CategoryRelations.products),
    ),
  ],
);
