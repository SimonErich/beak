import 'package:superdashboard/models/models.dart';

import 'seed_context.dart';
import 'seed_ids.dart';

/// One board-column definition.
typedef _Column = ({String name, String color, int? wip});

/// Seeds the Kanban domain: one board, its columns, labelled cards, and
/// their members.
final class KanbanSeeder {
  /// Creates the seeder.
  const KanbanSeeder();

  static const List<_Column> _columns = [
    (name: 'Backlog', color: '#6b7280', wip: null),
    (name: 'In Progress', color: '#0ea5e9', wip: 5),
    (name: 'Review', color: '#f59e0b', wip: 3),
    (name: 'Done', color: '#22c55e', wip: null),
  ];

  static const List<String> _labelNames = [
    'Bug',
    'Feature',
    'Design',
    'Urgent',
    'Docs',
  ];

  static const List<String> _cardTitles = [
    'Fix login redirect loop',
    'Design empty states',
    'Add CSV export',
    'Optimize dashboard query',
    'Write onboarding docs',
    'Refactor auth service',
    'Ship dark mode',
    'Investigate flaky test',
    'Update pricing page',
    'Add keyboard shortcuts',
    'Improve chart tooltips',
    'Migrate to new API',
    'Audit accessibility',
    'Set up staging deploy',
    'Reduce bundle size',
    'Add rate limiting',
  ];

  /// Seeds all Kanban-domain rows through [ctx].
  Future<void> seed(SeedContext ctx) async {
    await ctx.insert('boards', {
      'id': SeedIds.board,
      'name': 'Product Roadmap',
      'description': ctx.faker.sentence(wordCount: 8),
      'owner_id': SeedIds.userAisha,
      'created_at': ctx.daysAgo(200),
    });

    final columnIds = <String>[];
    final columnRows = <Map<String, Object?>>[];
    for (var index = 0; index < _columns.length; index++) {
      final id = ctx.uuid();
      columnIds.add(id);
      columnRows.add({
        'id': id,
        'board_id': SeedIds.board,
        'name': _columns[index].name,
        'sort_index': index,
        'color': _columns[index].color,
        'wip_limit': _columns[index].wip,
      });
    }
    await ctx.insertMany('board_columns', columnRows);

    final labelIds = <String>[];
    final labelRows = <Map<String, Object?>>[];
    for (final name in _labelNames) {
      final id = ctx.uuid();
      labelIds.add(id);
      labelRows.add({'id': id, 'name': name, 'color': ctx.faker.hexColor()});
    }
    await ctx.insertMany('card_labels', labelRows);

    final cardRows = <Map<String, Object?>>[];
    final cardLabelRows = <Map<String, Object?>>[];
    final cardUserRows = <Map<String, Object?>>[];
    for (var index = 0; index < _cardTitles.length; index++) {
      final id = ctx.uuid();
      cardRows.add({
        'id': id,
        'column_id': ctx.pick(columnIds),
        'title': _cardTitles[index],
        'description': ctx.faker.paragraph(sentenceCount: 2),
        'due_date': ctx.around(25),
        'priority': ctx.weighted({
          Priority.low.name: 2,
          Priority.medium.name: 4,
          Priority.high.name: 3,
          Priority.urgent.name: 1,
        }),
        'cover_image': ctx.chance(0.3)
            ? ctx.faker.imageUrl(width: 480, height: 240)
            : null,
        'sort_index': index,
        'attachments_count': ctx.between(0, 5),
        'comments_count': ctx.between(0, 12),
      });
      final labels = <String>{};
      final labelCount = ctx.between(1, 2);
      while (labels.length < labelCount) {
        labels.add(ctx.pick(labelIds));
      }
      for (final labelId in labels) {
        cardLabelRows.add({'card_id': id, 'card_label_id': labelId});
      }
      final members = <String>{};
      final memberCount = ctx.between(1, 3);
      while (members.length < memberCount) {
        members.add(ctx.pick(SeedIds.heroUsers));
      }
      for (final userId in members) {
        cardUserRows.add({'card_id': id, 'user_id': userId});
      }
    }
    await ctx.insertMany('cards', cardRows);
    await ctx.insertMany('card_card_label', cardLabelRows);
    await ctx.insertMany('card_user', cardUserRows);
  }
}
