/// The Beak reference admin backend: shared models wired into a
/// `BeakServer`, with worm migrations and seeders for the catalog schema.
library;

export 'src/migrations/reference_migrations.dart';
export 'src/seeders/reference_seeder.dart';
export 'src/server_builder.dart';
