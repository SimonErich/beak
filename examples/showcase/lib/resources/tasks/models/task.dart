import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../../habitats/models/habitat.dart';
import '../../keepers/models/keeper.dart';

part 'task.beak.dart';

/// Where a task stands; the columns of the board.
enum TaskStatus {
  /// Not started.
  todo,

  /// Being worked on.
  doing,

  /// Finished.
  done,
}

/// The kind of chore, which colours the calendar.
enum TaskCategory {
  /// Feeding round.
  feeding,

  /// Cleaning the aviary.
  cleaning,

  /// Vet visit or medication.
  medical,

  /// Toys, perches and puzzles.
  enrichment,
}

/// A chore on the aviary's board and calendar.
// --8<-- [start:Task]
@Resource(timestamps: true)
final class Task extends BeakSchema {
  /// What has to be done.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(160)])
  late final String title;

  /// Where the task stands (groups the kanban board).
  @Column(defaultValue: TaskStatus.todo, filterable: true)
  @Badges<TaskStatus>({
    TaskStatus.todo: BeakColor.muted,
    TaskStatus.doing: BeakColor.info,
    TaskStatus.done: BeakColor.success,
  })
  late final TaskStatus status;

  /// The kind of chore (colours the calendar).
  @Column(defaultValue: TaskCategory.feeding, filterable: true)
  late final TaskCategory category;

  /// Board order inside a column.
  @Column(sortable: true, defaultValue: 0)
  late final int position;

  /// When the task starts (places it on the calendar).
  @Column(sortable: true)
  late final DateTime startsAt;

  /// When the task ends.
  late final DateTime? endsAt;

  /// Whether the task lasts all day.
  late final bool allDay;

  /// Who is on the hook.
  @BelongsTo(onDelete: BeakOnDelete.setNull, inverse: false)
  late final Keeper? assignee;

  /// The habitat the task is about.
  @BelongsTo(onDelete: BeakOnDelete.setNull, inverse: false)
  late final Habitat? habitat;
}
// --8<-- [end:Task]
