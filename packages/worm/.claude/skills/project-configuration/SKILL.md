---
name: project-configuration
description: Rules for configuration management — .env secrets, lib/config/ typed constants, env abstraction, .env.example, and Serverpod passwords.yaml migration. Use when adding config values, secrets, environment variables, or setting up a new project.
role: reference
scope: general
trigger: auto_with_workflow
pairs_with:
  - serverpod-configuration
  - error-handling
  - getting-started
---

# Project Configuration

Use this skill when adding configuration values, environment variables, secrets, or setting up a new project. It defines how all configuration is managed across Flutter, Dart CLI, and Serverpod projects.

## Quick Start

There are exactly two places for configuration:

| What | Where | Committed to git? |
|------|-------|--------------------|
| Secrets (API keys, passwords, tokens) | `.env` file | Never (`.gitignore`d) |
| Non-secret config (feature flags, limits, URLs, thresholds) | `lib/config/{topic}.dart` | Always |

Both categories follow one absolute rule: **environment variables are never accessed directly in application code**.

## The Golden Rule

> **No `.env` variable is ever read outside of `lib/config/`.**

Every environment variable must be abstracted through a typed config property in `lib/config/`. This guarantees:

- A single, searchable inventory of every env dependency.
- A central place to add validation, defaults, or transformations.
- Application code never breaks when env key names change.
- Secrets are contained — only config files touch `dotenv`.

**Violation example (forbidden):**

```dart
// BAD — direct dotenv access in a repository
final url = dotenv.env['API_URL']!;
```

**Correct:**

```dart
// lib/config/app.dart — single point of env access
abstract final class AppConfig {
  /// The base URL for the main backend API.
  ///
  /// Sourced from the `APP_API_URL` environment variable.
  /// Must include the scheme (https://) and no trailing slash.
  ///
  /// Examples:
  /// - Development: `http://localhost:8080`
  /// - Production: `https://api.example.com`
  static final String apiUrl = dotenv.env['APP_API_URL']!;
}

// In a repository — uses the config abstraction
final url = AppConfig.apiUrl;
```

## `.env` File Rules

### Location

- **Flutter / Dart CLI projects:** `.env` in the project root.
- **Serverpod projects:** one `.env` per package (see Serverpod section below).

### Gitignore

Every `.env` file must be in `.gitignore`. No exceptions.

```gitignore
# Environment files
.env
.env.*
!.env.example
```

### Key Naming

Use **domain-prefixed SCREAMING_SNAKE_CASE**:

```bash
# Good — prefixed, clear domain
APP_API_URL=https://api.example.com
APP_SUPPORT_EMAIL=help@example.com
DB_HOST=localhost
DB_PORT=5432
DB_PASSWORD=secret
AUTH_CLIENT_ID=abc123
SMTP_API_KEY=xyz
STRIPE_SECRET_KEY=sk_live_...

# Bad — no prefix, ambiguous
URL=https://api.example.com
HOST=localhost
KEY=abc123
```

### `.env.example` (Mandatory)

Every project must have a `.env.example` committed to git. It documents every required key with:

- A comment describing the variable's purpose.
- A safe placeholder value (never real secrets).
- Grouping by domain.

```bash
# .env.example
# Copy this file to .env and fill in real values.

# === App ===
# Base URL for the main backend API (include scheme, no trailing slash)
APP_API_URL=https://api.example.com

# === Database ===
# PostgreSQL connection details
DB_HOST=localhost
DB_PORT=5432
DB_PASSWORD=your-database-password-here

# === Auth ===
# OAuth client ID from the provider dashboard
AUTH_CLIENT_ID=your-client-id-here

# === Email ===
# SMTP provider API key
SMTP_API_KEY=your-smtp-api-key-here
```

### Loading `.env`

Use the `flutter_dotenv` package. Load in `main()` before any config access:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load(fileName: '.env');
  // Now config files can safely read dotenv.env[...]
  runApp(const MyApp());
}
```

For Dart CLI projects, use the `dotenv` package with the same pattern.

## `lib/config/` Structure

### File Layout

One file per topic, one `abstract final class` per file:

```
lib/config/
├── app.dart            → abstract final class AppConfig
├── database.dart       → abstract final class DatabaseConfig
├── notifications.dart  → abstract final class NotificationsConfig
├── vouchers.dart       → abstract final class VouchersConfig
├── invoices.dart       → abstract final class InvoicesConfig
└── auth.dart           → abstract final class AuthConfig
```

### Naming

- File: `lib/config/{topic}.dart` — named by rough domain context.
- Class: `abstract final class {Topic}Config` — non-instantiable, static members only.

### Property Rules

Every property must be:

- **Strictly typed** — `String`, `int`, `double`, `bool`, `Duration`, enum, etc. Never `dynamic` or `Object`.
- **`static const`** for compile-time values, **`static final`** for runtime values (e.g., from `.env`).
- **Extensively documented** — each property gets a doc comment covering:
  - **What** the value controls.
  - **Why** it exists and when you might change it.
  - **Type and constraints** (range, format, allowed values).
  - **Examples** of typical values per environment or use case.
  - **Source** — if from `.env`, name the env key.

### Full Example

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central configuration for the core application behavior.
///
/// Contains API endpoints, feature flags, and app-wide defaults.
/// Values sourced from `.env` are marked with their env key name.
abstract final class AppConfig {
  // ---------------------------------------------------------------------------
  // Environment-sourced values
  // ---------------------------------------------------------------------------

  /// The base URL for the main backend API.
  ///
  /// Sourced from the `APP_API_URL` environment variable.
  /// Must include the scheme (https://) and no trailing slash.
  ///
  /// Examples:
  /// - Development: `http://localhost:8080`
  /// - Staging: `https://staging.api.example.com`
  /// - Production: `https://api.example.com`
  static final String apiUrl = dotenv.env['APP_API_URL']!;

  /// Contact email shown in support screens and error dialogs.
  ///
  /// Sourced from the `APP_SUPPORT_EMAIL` environment variable.
  /// Used in the "Contact Support" button and in crash report footers.
  static final String supportEmail = dotenv.env['APP_SUPPORT_EMAIL']!;

  // ---------------------------------------------------------------------------
  // Compile-time constants
  // ---------------------------------------------------------------------------

  /// Whether to show debug overlays, logging panels, and dev tools.
  ///
  /// Set to `true` during development to enable:
  /// - Network request inspector
  /// - State viewer overlay
  /// - Verbose console logging
  ///
  /// Must be `false` in production builds.
  static const bool debugMode = true;

  /// Maximum number of retry attempts for failed API requests.
  ///
  /// Applies to transient failures (timeouts, 5xx responses).
  /// Does not apply to client errors (4xx).
  /// Retries use exponential backoff starting at 1 second.
  ///
  /// Typical values: 2–5. Set to 0 to disable retries.
  static const int maxApiRetries = 3;

  /// Duration before an API request is considered timed out.
  ///
  /// Applies to all HTTP calls made through the API client.
  /// Should be generous enough for slow connections but short
  /// enough to fail fast when the server is unreachable.
  ///
  /// Typical values: 10–30 seconds.
  static const Duration apiTimeout = Duration(seconds: 15);

  /// The minimum app version required to use the current API.
  ///
  /// Compared against the running app version on startup.
  /// If the running version is below this, a force-update
  /// dialog is shown. Update this when deploying breaking
  /// API changes.
  ///
  /// Format: semantic version string (e.g., '2.1.0').
  static const String minimumAppVersion = '1.0.0';
}
```

### What Belongs Here (and What Does Not)

**Yes — put it in `lib/config/`:**

- Feature flags and toggles (`debugMode`, `enableBetaFeatures`)
- Limits and thresholds (`maxUploadSizeMb`, `sessionTimeoutMinutes`)
- URLs and endpoints (abstracted from `.env`)
- Display defaults that might change (`defaultPageSize`, `maxSearchResults`)
- Version constraints (`minimumAppVersion`)
- Provider-specific IDs abstracted from `.env` (`analyticsId`, `sentryDsn`)

**No — do not put here:**

- Business logic constants tightly coupled to a single class (keep them local).
- Generated values or computed state.
- UI theme values (those belong in the theme system).
- Strings/translations (those belong in l10n).
- Constants that are truly universal and will never change (`pi`, `maxInt`).

## Serverpod Projects

### Package-Level Isolation

Serverpod projects have multiple packages. Each package that needs configuration gets its own `.env` and `lib/config/`:

```
my_project/
├── my_project_server/
│   ├── .env                  ← Server secrets (DB passwords, API keys, service secrets)
│   ├── .env.example
│   └── lib/config/
│       ├── database.dart     → DatabaseConfig (reads DB_* from .env)
│       ├── server.dart       → ServerConfig (reads SERVER_* from .env)
│       └── services.dart     → ServicesConfig (reads STRIPE_*, SMTP_* from .env)
│
├── my_project_shared/
│   └── lib/config/
│       └── shared.dart       → SharedConfig (compile-time constants only, NO .env)
│
├── my_project_client/        (typically no config needed)
│
└── my_project_flutter/
    ├── .env                  ← App-level config only (NO secrets)
    ├── .env.example
    └── lib/config/
        ├── app.dart          → AppConfig (reads APP_* from .env)
        └── features.dart     → FeaturesConfig (compile-time constants)
```

**Critical rule:** The Flutter package `.env` must never contain secrets. Server-only secrets (database passwords, service API keys, signing keys) live exclusively in the server package `.env`.

### Migrating from `passwords.yaml`

To migrate an existing Serverpod project away from `passwords.yaml`:

1. **Create the server `.env`** with all secrets from `passwords.yaml`:

   ```bash
   # my_project_server/.env
   DB_PASSWORD=your-actual-password
   REDIS_PASSWORD=your-redis-password
   SERVERPOD_SERVICE_SECRET=your-service-secret
   STRIPE_SECRET_KEY=sk_live_...
   ```

2. **Create `.env.example`** with placeholder values and commit it.

3. **Add `passwords.yaml` and `.env` to `.gitignore`:**

   ```gitignore
   config/passwords.yaml
   .env
   .env.*
   !.env.example
   ```

4. **Create `lib/config/database.dart`** (and other config files as needed):

   ```dart
   import 'package:dotenv/dotenv.dart';

   abstract final class DatabaseConfig {
     /// PostgreSQL password.
     ///
     /// Sourced from the `DB_PASSWORD` environment variable.
     /// Replaces the former `passwords.yaml` → `database` key.
     static final String password = dotenv.env['DB_PASSWORD']!;
   }
   ```

5. **Update server startup** to load `.env` before Serverpod initializes:

   ```dart
   import 'package:dotenv/dotenv.dart' as dotenv;

   void main() async {
     dotenv.load('.env');

     // Serverpod picks up SERVERPOD_PASSWORD_* from environment
     // Set them from our .env for local development:
     // (In production, set these as real environment variables)
     final pod = Serverpod(...);
     await pod.start();
   }
   ```

6. **Remove `passwords.yaml`** from the repository (ensure it is gitignored first so it is not re-committed).

### Serverpod Environment Variable Bridge

For Serverpod's built-in `SERVERPOD_PASSWORD_*` variables, bridge them through config:

```dart
abstract final class ServerpodSecretsConfig {
  /// Database password for Serverpod's internal ORM connection.
  ///
  /// Sourced from `DB_PASSWORD` env var.
  /// Serverpod reads `SERVERPOD_PASSWORD_database` — set this in your
  /// deployment environment or docker-compose, not in application code.
  static final String databasePassword = dotenv.env['DB_PASSWORD']!;

  /// Service secret used for server-to-server authentication.
  ///
  /// Sourced from `SERVERPOD_SERVICE_SECRET` env var.
  static final String serviceSecret = dotenv.env['SERVERPOD_SERVICE_SECRET']!;
}
```

## What Goes Where — Decision Table

| Scenario | Where | Example |
|----------|-------|---------|
| Secret (password, API key, token) | `.env` → abstracted in `lib/config/` | `DB_PASSWORD` → `DatabaseConfig.password` |
| Non-secret, env-dependent (URL, email) | `.env` → abstracted in `lib/config/` | `APP_API_URL` → `AppConfig.apiUrl` |
| Non-secret, needs tweaking | `lib/config/` as `static const` | `AppConfig.maxApiRetries = 3` |
| Non-secret, never changes | Inline where used or `lib/config/` | Judgment call — prefer `lib/config/` if others might look for it |

## Anti-Patterns

| Anti-Pattern | Why It's Wrong | Fix |
|--------------|----------------|-----|
| `dotenv.env['X']` outside `lib/config/` | Breaks the golden rule; scatters env dependencies | Move to a config class |
| Real secrets in `passwords.yaml` committed to git | Security risk | Migrate to `.env`, gitignore both |
| Untyped config (`dynamic`, `Object`) | Violates project type safety rules | Use specific types |
| Undocumented config property | Nobody knows what it does or why | Add full doc comment |
| Config file as catch-all constant dump | Defeats the purpose of topical organization | Split by domain, keep focused |
| Hardcoded secrets in Dart source | Security risk, hard to rotate | Move to `.env` |
| Flutter `.env` containing server secrets | Secrets compiled into client binary | Keep server secrets in server `.env` only |
