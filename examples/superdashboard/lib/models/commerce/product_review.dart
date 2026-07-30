import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../people/user.dart';
import 'product.dart';

part 'product_review.beak.dart';

/// The product-reviews resource — a customer rating and write-up.
@Resource()
final class ProductReview extends BeakSchema {
  /// Star rating, 1–5.
  @Column(min: 1, max: 5, sortable: true, rules: [BeakMin(1), BeakMax(5)])
  late final int rating;

  /// Review headline.
  @Display()
  @Column(searchable: true, rules: [BeakMaxLength(160)])
  late final String title;

  /// Review body.
  @Column(label: 'Review')
  late final BeakText? body;

  /// The reviewer's display name (denormalized for quick reads).
  @Column(label: 'Reviewer', searchable: true)
  late final String? authorName;

  /// When the review was written.
  @Column(label: 'Written', sortable: true)
  late final DateTime? createdAt;

  /// The reviewed product.
  @BelongsTo()
  late final Product? product;

  /// The reviewing user.
  @BelongsTo()
  late final User? user;
}
