import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../people/user.dart';
import 'board_column.dart';

part 'board.beak.dart';

/// The boards resource — a kanban project board.
@Resource(timestamps: true)
final class Board extends BeakSchema {
  /// Board name.
  @Display()
  @Column(sortable: true, searchable: true, rules: [BeakMaxLength(120)])
  late final String name;

  /// Board description.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? description;

  /// The owning user.
  @BelongsTo()
  late final User? owner;

  /// The columns on this board.
  @HasMany()
  late final List<BoardColumn> columns;
}
