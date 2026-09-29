import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import '../resources/invoices/models/invoice.dart';
import '../resources/sightings/models/sighting.dart';
import '../resources/specimens/models/specimen.dart';
import '../resources/tasks/models/task.dart';
import '../seeders/aviary_dates.dart';

/// Blocks bound to data: metrics, summaries, a scoped table and a timeline.
///
/// This is the landing page.
BeakScreen dataBlocksPage() => BeakScreen(
  path: '/',
  title: 'Data blocks',
  icon: const BeakIconToken(OiIcons.layoutDashboard),
  navigationGroup: 'Blocks',
  body: BeakColumnBlock(
    gapInPixels: 24,
    children: [
      _metrics(),
      _summaries(),
      BeakGridBlock(
        minColumnWidthInPixels: 480,
        children: [_upcomingTasks(), _taskTimeline()],
      ),
    ],
  ),
);

/// Live aggregates, one card each.
// --8<-- [start:metrics]
BeakBlock _metrics() => BeakGridBlock(
  minColumnWidthInPixels: 220,
  children: [
    BeakMetricBlock(
      label: 'Specimens',
      icon: OiIcons.bird,
      aggregate: const SpecimenModel().count(),
      target: 60,
    ),
    BeakMetricBlock(
      label: 'Endangered',
      icon: OiIcons.egg,
      aggregate: const SpecimenModel().count(
        filter: SpecimenModel.endangered.eq(true),
      ),
    ),
    BeakMetricBlock(
      label: 'Average weight',
      icon: OiIcons.feather,
      aggregate: const SpecimenModel().avg(SpecimenModel.weightInGrams),
      unit: 'g',
    ),
    BeakMetricBlock(
      label: 'Birds seen, second fortnight',
      icon: OiIcons.trees,
      aggregate: const SightingModel().sum(
        SightingModel.birdsSeen,
        filter: SightingModel.spottedOn.gte(AviaryDates.secondFortnightStart),
      ),
      previous: const SightingModel().sum(
        SightingModel.birdsSeen,
        filter: SightingModel.spottedOn.lt(AviaryDates.secondFortnightStart),
      ),
    ),
    BeakMetricBlock(
      label: 'Feed invoiced',
      icon: OiIcons.receiptText,
      aggregate: const InvoiceModel().sum(InvoiceModel.total),
      format: BeakValueFormat.currency,
    ),
  ],
);
// --8<-- [end:metrics]

/// Grouped figures in every presentation the summary block has.
// --8<-- [start:summaries]
BeakBlock _summaries() {
  const tasks = BeakSummaryMeasure.count('tasks');
  final done = BeakSummaryMeasure.count(
    'done',
    filter: TaskModel.status.eq(TaskStatus.done),
  );
  const birds = BeakSummaryMeasure.count('birds');
  final grams = BeakSummaryMeasure.sum(
    'grams',
    field: SpecimenModel.weightInGrams,
  );
  return BeakGridBlock(
    minColumnWidthInPixels: 420,
    children: [
      BeakSummaryBlock(
        title: 'Tasks by status',
        presentation: BeakSummaryPresentation.donut,
        scope: BeakSummaryScope.standalone,
        query: const TaskModel().summary(
          groupBy: TaskModel.status,
          measures: [tasks],
        ),
        values: [const BeakSummaryValue(measure: tasks, label: 'Tasks')],
        centerLabel: 'tasks',
      ),
      BeakSummaryBlock(
        title: 'Birds and weight by diet',
        presentation: BeakSummaryPresentation.bar,
        scope: BeakSummaryScope.standalone,
        showTableToggle: true,
        query: const SpecimenModel().summary(
          groupBy: SpecimenModel.diet,
          measures: [birds, grams],
        ),
        values: [
          const BeakSummaryValue(measure: birds, label: 'Birds'),
          BeakSummaryValue(measure: grams, label: 'Grams'),
        ],
      ),
      BeakSummaryBlock(
        title: 'Chores done',
        presentation: BeakSummaryPresentation.capacity,
        scope: BeakSummaryScope.standalone,
        query: const TaskModel().summary(
          groupBy: TaskModel.category,
          measures: [done, tasks],
        ),
        values: [
          BeakSummaryValue(measure: done, label: 'Done'),
          const BeakSummaryValue(measure: tasks, label: 'All'),
        ],
        capacity: BeakSummaryCapacity(used: done, total: tasks),
      ),
      BeakSummaryBlock(
        title: 'The collection at a glance',
        presentation: BeakSummaryPresentation.strip,
        scope: BeakSummaryScope.standalone,
        query: const SpecimenModel().summary(measures: [birds, grams]),
        values: [
          const BeakSummaryValue(
            measure: birds,
            label: 'birds',
            icon: OiIcons.bird,
            iconColor: BeakColor.primary,
          ),
          BeakSummaryValue(
            measure: grams,
            label: 'grams in all',
            icon: OiIcons.feather,
          ),
        ],
      ),
      BeakSummaryBlock(
        title: 'Tasks by category',
        presentation: BeakSummaryPresentation.table,
        scope: BeakSummaryScope.standalone,
        query: const TaskModel().summary(
          groupBy: TaskModel.category,
          measures: [tasks, done],
        ),
        values: [
          const BeakSummaryValue(measure: tasks, label: 'Tasks'),
          BeakSummaryValue(measure: done, label: 'Done'),
        ],
      ),
      BeakSummaryBlock(
        title: 'Tasks in total',
        scope: BeakSummaryScope.standalone,
        query: const TaskModel().summary(measures: [tasks, done]),
        values: [
          const BeakSummaryValue(measure: tasks, label: 'Tasks'),
          BeakSummaryValue(measure: done, label: 'Done'),
        ],
      ),
    ],
  );
}
// --8<-- [end:summaries]

/// A table scoped to open work, five rows.
// --8<-- [start:upcomingTasks]
BeakBlock _upcomingTasks() => BeakCardBlock(
  title: 'Upcoming tasks',
  child: BeakTableBlock(
    model: const TaskModel(),
    fields: [
      TaskModel.title,
      TaskModel.category,
      TaskModel.status,
      TaskModel.startsAt,
    ],
    enableDelete: false,
    initialSpec: const TaskModel().query(
      sorts: [TaskModel.startsAt.ascending()],
      pagination: const BeakPagination(perPage: 5),
    ),
    baseFilter: TaskModel.status.notEq(TaskStatus.done),
  ),
);
// --8<-- [end:upcomingTasks]

/// Events in time order.
// --8<-- [start:taskTimeline]
BeakBlock _taskTimeline() => BeakCardBlock(
  title: 'Recent tasks',
  child: BeakTimelineBlock(
    query: const TaskModel().query(
      sorts: [TaskModel.startsAt.descending()],
      pagination: const BeakPagination(perPage: 8),
    ),
    titleField: TaskModel.title.column,
    timeField: TaskModel.startsAt.column,
  ),
);
// --8<-- [end:taskTimeline]

/// The chores as a board and as a calendar.
BeakScreen plannerPage() => BeakScreen(
  path: '/planner',
  title: 'Planner',
  icon: const BeakIconToken(OiIcons.kanban),
  navigationGroup: 'Blocks',
  framed: false,
  body: BeakTabsBlock(
    tabs: [
      BeakTabBlockItem(label: 'Board', content: _board()),
      BeakTabBlockItem(label: 'Calendar', content: _calendar()),
    ],
  ),
);

/// One column per status.
// --8<-- [start:board]
BeakBlock _board() => BeakKanbanBlock(
  model: const TaskModel(),
  groupField: TaskModel.status,
  titleField: TaskModel.title.column,
  subtitleField: TaskModel.category.column,
  sortField: TaskModel.position.column,
  label: 'Chores',
);
// --8<-- [end:board]

/// Chores placed by their start and end.
// --8<-- [start:calendar]
BeakBlock _calendar() => BeakCalendarBlock(
  model: const TaskModel(),
  titleField: TaskModel.title.column,
  startField: TaskModel.startsAt.column,
  endField: TaskModel.endsAt.column,
  allDayField: TaskModel.allDay.column,
  categoryField: TaskModel.category.column,
  label: 'Chore calendar',
);
// --8<-- [end:calendar]
