import 'package:worm/worm.dart';

import 'analytics_seeder.dart';
import 'calendar_seeder.dart';
import 'chat_seeder.dart';
import 'commerce_seeder.dart';
import 'content_seeder.dart';
import 'email_seeder.dart';
import 'files_seeder.dart';
import 'invoices_seeder.dart';
import 'kanban_seeder.dart';
import 'people_seeder.dart';
import 'seed_context.dart';

/// The master seeder: builds one shared, deterministically-seeded
/// [SeedContext] and runs every domain seeder through it in dependency order.
///
/// A single context means one continuous faker stream, so values stay unique
/// across domains and the whole database reproduces byte-for-byte. People run
/// first (the identity spine), then Commerce, then Analytics — which rolls up
/// the exact orders Commerce inserted so the dashboard reconciles.
final class DemoDatabaseSeeder extends Seeder {
  /// Creates the master seeder.
  const DemoDatabaseSeeder();

  @override
  String get name => 'DemoDatabaseSeeder';

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    final ctx = SeedContext(adapter);
    await const PeopleSeeder().seed(ctx);
    await const CommerceSeeder().seed(ctx);
    await const AnalyticsSeeder().seed(ctx);
    await const EmailSeeder().seed(ctx);
    await const ChatSeeder().seed(ctx);
    await const CalendarSeeder().seed(ctx);
    await const FilesSeeder().seed(ctx);
    await const InvoicesSeeder().seed(ctx);
    await const KanbanSeeder().seed(ctx);
    await const ContentSeeder().seed(ctx);
  }
}
