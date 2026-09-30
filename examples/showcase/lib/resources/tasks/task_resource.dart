import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import 'models/task.dart';

/// The chores, also shown as a board and a calendar on the data page.
final class TaskResource extends BeakResource {
  /// Creates the tasks section.
  TaskResource()
    : super(
        model: const TaskModel(),
        title: 'Tasks',
        icon: const BeakIconToken(OiIcons.listChecks),
        navigationGroup: 'Team',
        navigationRank: 4,
        globalSearchSources: [TaskModel.title],
        filters: [
          TaskModel.status.selectFilter(),
          TaskModel.category.selectFilter(),
        ],
        screens: [
          BeakTableScreen(
            fields: [
              TaskModel.title,
              TaskModel.status,
              TaskModel.category,
              TaskModel.startsAt,
              TaskModel.assignee.name.formatted(
                BeakValueFormat.text,
                label: 'Assignee',
              ),
            ],
          ),
        ],
      );
}
