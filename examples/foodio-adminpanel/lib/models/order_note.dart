import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'models.dart';
import '../domain/foodio_clock.dart';

part 'order_note.beak.dart';

/// OrderNote configuration shared by the panel and authoritative API.
@Resource(timestamps: true)
final class OrderNote extends BeakSchema {
  /// The form gets a useful preview; the server supplies the authoritative actor.
  static BeakModelBehavior get behavior => BeakModelBehavior(
    values: [
      BeakValueBehavior.initial(
        field: OrderNoteModel.occurredAt,
        resolve: (_) => const FoodioClock().now,
      ),
    ],
  );

  /// Body.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String body;

  /// Order.
  @BelongsTo(onDelete: BeakOnDelete.cascade)
  late final Order order;

  /// Author.
  @Column(defaultValue: 'Marie Novak')
  late final String author;

  /// Author role captured when the note was written, preserved as audit history.
  @Column()
  late final String? authorRole;

  /// Visibility.
  @Column(defaultValue: 'internal')
  late final String visibility;

  /// Occurred at.
  @Column(sortable: true, filterable: true)
  late final DateTime occurredAt;
}
