/// Every superdashboard migration, aggregated in dependency order — the list
/// the worm CLI and the E2E harness run.
library;

import 'package:worm/worm.dart';

import 'analytics_migrations.dart';
import 'calendar_migrations.dart';
import 'chat_migrations.dart';
import 'commerce_migrations.dart';
import 'content_migrations.dart';
import 'email_migrations.dart';
import 'files_migrations.dart';
import 'invoices_migrations.dart';
import 'kanban_migrations.dart';
import 'people_migrations.dart';

/// The migrations in dependency-correct order: People first (the identity
/// spine every other domain's foreign keys point at), then the domains that
/// reference it.
const List<Migration> demoMigrations = [
  CreatePeopleTables(),
  CreateCommerceTables(),
  CreateAnalyticsTables(),
  CreateEmailTables(),
  CreateChatTables(),
  CreateCalendarTables(),
  CreateFilesTables(),
  CreateInvoicesTables(),
  CreateKanbanTables(),
  CreateContentTables(),
  AddSortIndexToActivityHeatmap(),
];
