import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../people/user.dart';
import 'order.dart';

part 'order_comment.beak.dart';

/// The order-comments resource — an internal or customer-facing note.
@Resource()
final class OrderComment extends BeakSchema {
  /// The comment text.
  @Display()
  @Column(label: 'Comment', searchable: true)
  late final BeakText body;

  /// Whether the note is internal (staff-only) or customer-visible.
  @Column(label: 'Internal')
  late final bool? isInternal;

  /// The author's display name (denormalized for quick reads).
  @Column(label: 'Author', searchable: true)
  late final String? authorName;

  /// When the comment was written.
  @Column(label: 'When', sortable: true)
  late final DateTime? createdAt;

  /// The owning order.
  @BelongsTo()
  late final Order? order;

  /// The authoring user.
  @BelongsTo()
  late final User? author;
}
