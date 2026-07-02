---
name: create-reusable-helpers
description: Mandatory guardrail companion for extracting utility functions, helpers, formatters, extensions, or shared logic reused across more than one call site or file. Prevents one-off helpers, bad placement, and undocumented duplication. Do not use this skill for widget extraction; use `flutter-widget-composition` for that.
role: guardrail
scope: general
trigger: auto_with_workflow
pairs_with:
  - refactor-provider
  - qa-review
---

# Create Reusable Helpers

This skill constrains helper extraction decisions. Let a task-specific workflow own the task when the user is doing broader implementation work.

## Before Writing Any Helper

### Step 1: Check if it already exists

Search before creating:

- `<project>_flutter/lib/core/utils/`
- `<project>_flutter/lib/core/formatter/`
- `<project>_flutter/lib/core/hooks/`
- `<project>_flutter/lib/uikit/utils/`
- `<project>_flutter/lib/features/*/domain/extensions/`
- `<project>_server/lib/src/core/utils/`

If something similar exists, extend or parameterize it — don't duplicate.

If the logic is domain-specific business logic rather than a reusable helper, stop and move it into a UseCase or application class instead.

### Step 2: Determine scope

| Used by... | Flutter Location | Server Location |
|-----------|------------------|-----------------|
| 2+ features | `lib/core/utils/` | `lib/src/core/utils/` |
| 1 feature only | `lib/features/<feature>/utils/` | `lib/src/features/<feature>/utils/` |
| UI-specific | `lib/features/<feature>/presentation/helpers/` | N/A |
| Extension on model | `lib/features/<feature>/domain/extensions/` | N/A |
| UIKit utility | `lib/uikit/utils/` | N/A |
| Mapper | `lib/features/<feature>/domain/mappers/` | `lib/src/features/<feature>/mappers/` |
| Formatter | `lib/core/formatter/` | N/A |

### Step 3: Think generically

Before implementing, consider:

1. Can input types be more general? (`Iterable<T>` instead of `List<T>`)
2. Can behavior be parameterized? (comparison function instead of hardcoded sort)
3. Are there related operations to co-locate? (normalize + validate + compare)
4. Should you use a library instead? (CSV parsing, HTML templating, date math)

## Implementation Rules

### Pure Functions Only

```dart
// CORRECT — pure, no side effects
class VoucherCodeNormalizer {
  static String normalize(String code) {
    return code.trim().toUpperCase().replaceAll(RegExp(r'[\s\-_\.]'), '');
  }

  static bool areEqual(String code1, String code2) {
    return normalize(code1) == normalize(code2);
  }
}

// WRONG — has side effects
String normalize(String code) {
  _lastNormalized = code; // Side effect!
  return code.trim().toUpperCase();
}
```

### Documentation Required

```dart
/// Converts a UUID string to an integer user ID.
///
/// Uses SHA-256 of the full UUID string and extracts the first 7 bytes as a
/// positive integer that fits in JavaScript's safe integer range (2^53 - 1).
///
/// Returns `null` if the input is null.
int? uuidToUserId(String? uuid) { ... }
```

Required:
- **What** it does (first line)
- **How** it works (if non-obvious)
- **Edge cases** / null behavior
- **Cross-references** to related code

### Configurability

```dart
// WRONG — hardcoded
int truncateText(String text) => text.length > 50 ? 50 : text.length;

// CORRECT — parameterized
String truncateText(String text, {int maxLength = 50, String suffix = '...'}) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength - suffix.length)}$suffix';
}
```

### Immutability

Result types must be immutable:
```dart
class ValidationResult {
  const ValidationResult._({required this.isValid, this.error});

  factory ValidationResult.valid() => const ValidationResult._(isValid: true);
  factory ValidationResult.invalid(String error) =>
    ValidationResult._(isValid: false, error: error);

  final bool isValid;
  final String? error;
}
```

## Testing Requirements

Every helper MUST have unit tests:

```dart
void main() {
  group('VoucherCodeNormalizer.normalize', () {
    test('trims whitespace', () {
      expect(VoucherCodeNormalizer.normalize('  ABC  '), 'ABC');
    });
    test('converts to uppercase', () {
      expect(VoucherCodeNormalizer.normalize('abc'), 'ABC');
    });
    test('handles empty string', () {
      expect(VoucherCodeNormalizer.normalize(''), '');
    });
  });
}
```

Cover: happy path, edge cases (empty, null, boundary), error cases.

## Anti-Patterns

- **DON'T** create a helper used in only one place — inline it
- **DON'T** put helpers in `lib/` root — use structured locations
- **DON'T** create mutable helper classes
- **DON'T** put business logic in helpers — that belongs in UseCases
- **DON'T** import `dart:io` in helpers used by Flutter web
- **DON'T** make helpers depend on GetIt or DI — helpers are pure
- **DON'T** reimplement standard library functionality — use packages
- **DON'T** duplicate existing validation, formatting, parsing, or normalization logic in a second location

## Checklist

- [ ] Searched codebase — no existing similar helper
- [ ] Correct location (core vs feature vs UIKit)
- [ ] Pure functions, no side effects
- [ ] Dartdoc comments on all public APIs
- [ ] Configurable via parameters
- [ ] Immutable result types
- [ ] Unit tests (happy path, edge cases, errors)
- [ ] No business logic, no DI dependencies
