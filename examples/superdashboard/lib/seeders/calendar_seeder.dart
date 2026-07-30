import 'seed_context.dart';
import 'seed_ids.dart';

/// One event-category definition.
typedef _Category = ({String name, String label, String color});

/// Seeds the Calendar domain: categories and events spanning the visible
/// month around the reference date, so the grid is always populated.
final class CalendarSeeder {
  /// Creates the seeder.
  const CalendarSeeder();

  static const List<_Category> _categories = [
    (name: 'business', label: 'Business', color: '#4f46e5'),
    (name: 'personal', label: 'Personal', color: '#10b981'),
    (name: 'family', label: 'Family', color: '#f59e0b'),
    (name: 'holiday', label: 'Holiday', color: '#ef4444'),
    (name: 'meeting', label: 'Meeting', color: '#0ea5e9'),
  ];

  static const List<String> _titles = [
    'Product sync',
    'Design review',
    'Team lunch',
    'Sprint planning',
    'Customer call',
    'Release window',
    '1:1 with Aisha',
    'Roadmap workshop',
    'Marketing standup',
    'Quarterly review',
  ];

  /// Seeds all Calendar-domain rows through [ctx].
  Future<void> seed(SeedContext ctx) async {
    final categoryIdByName = <String, String>{
      for (final category in _categories) category.name: ctx.uuid(),
    };
    final categoryRows = <Map<String, Object?>>[
      for (final category in _categories)
        {
          'id': categoryIdByName[category.name],
          'name': category.name,
          'label': category.label,
          'color': category.color,
        },
    ];
    await ctx.insertMany('event_categories', categoryRows);

    final eventRows = <Map<String, Object?>>[];
    final guestRows = <Map<String, Object?>>[];
    for (var index = 0; index < 22; index++) {
      final id = ctx.uuid();
      final category = ctx.pick(_categories);
      final allDay = ctx.chance(0.2);
      final start = ctx.around(20);
      final end = allDay
          ? start.add(const Duration(days: 1))
          : start.add(Duration(hours: ctx.between(1, 3)));
      eventRows.add({
        'id': id,
        'title': ctx.pick(_titles),
        'description': ctx.faker.sentence(wordCount: ctx.between(5, 12)),
        'category_id': categoryIdByName[category.name],
        'organizer_id': ctx.pick(SeedIds.heroUsers),
        'start_at': start,
        'end_at': end,
        'all_day': allDay,
        'color': category.color,
        'location': ctx.faker.city(),
        'url': null,
      });
      final guests = <String>{};
      final guestCount = ctx.between(0, 3);
      while (guests.length < guestCount) {
        guests.add(ctx.pick(SeedIds.heroUsers));
      }
      for (final guest in guests) {
        guestRows.add({'event_id': id, 'user_id': guest});
      }
    }
    await ctx.insertMany('calendar_events', eventRows);
    await ctx.insertMany('event_user', guestRows);
  }
}
