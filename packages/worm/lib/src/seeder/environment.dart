/// Seeder execution environments.
library;

/// Environment in which a seeder should run.
enum Environment {
  /// Local development environment.
  development,

  /// Pre-production staging environment.
  staging,

  /// Live production environment.
  production,

  /// Automated test environment.
  testing,

  /// Run in all environments.
  all,
}
