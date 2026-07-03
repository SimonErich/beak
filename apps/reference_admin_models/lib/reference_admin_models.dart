/// Shared Beak model definitions of the reference admin: Products, Users,
/// Orders, Categories, and Tags — declared once, consumed by both the
/// Shelf server and the Flutter panel.
library;

import 'package:beak_core/beak_core.dart';

import 'src/category.dart';
import 'src/order.dart';
import 'src/order_item.dart';
import 'src/product.dart';
import 'src/tag.dart';
import 'src/user.dart';

export 'src/category.dart';
export 'src/order.dart';
export 'src/order_item.dart';
export 'src/product.dart';
export 'src/tag.dart';
export 'src/user.dart';

/// Every reference model, in registration order.
const List<BeakModel> referenceModels = [
  ProductModel(),
  CategoryModel(),
  TagModel(),
  UserModel(),
  OrderModel(),
  OrderItemModel(),
];

/// Builds the registry over [referenceModels] — the single index both the
/// server and the panel hand to Beak.
BeakModelRegistry buildReferenceRegistry() {
  final registry = BeakModelRegistry();
  for (final model in referenceModels) {
    registry.register(model);
  }
  return registry;
}
