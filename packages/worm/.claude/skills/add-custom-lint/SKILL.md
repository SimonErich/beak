---
name: add-custom-lint
scope: general
description: Create a new custom lint rule in <project>_lints. Use when the user asks to add a lint rule, create a lint, enforce a code pattern, or add a static analysis check.
---

# Create Custom Lint Rule

## Template Package

This repo includes a pre-built `lints/` template package with 26 rules (9 core Dart, 11 Flutter, 6 Serverpod). Copy it into your project as `<project>_lints/`, rename the package in `pubspec.yaml`, and update imports. Add new project-specific rules following the steps below.

## Before you start

1. **Understand the requirement** — Ask clarifying questions if the rule scope or exceptions are unclear.
2. **Explore the codebase** — Use targeted `grep` in `<project>_flutter/lib/features/` to find 3–5 real examples of both violations and valid code. This grounds the rule in reality and catches edge cases early. Prefer direct grep/glob over the Explore agent for speed.
3. **Decide the analysis strategy:**
   - **Import-based rules** → use `context.registry.addImportDirective`
   - **File-level rules** (must inspect all classes/declarations in a file) → use `context.registry.addCompilationUnit`
   - **Per-class rules** → use `context.registry.addClassDeclaration`

## Project structure

```
<project>_lints/
  lib/
    <project>_lints.dart              # Plugin entry point — register rule here
    rules/
      feature_imports_classifier.dart  # Shared path classifier (reuse this)
      my_new_rule.dart                 # Your new rule file
  test/
    rules/
      my_new_rule_test.dart
```

## Step-by-step

### Step 1 — Create the rule file

Create `<project>_lints/lib/rules/<rule_name>_rule.dart`.

Use this template:

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analysis_server_plugin/analysis_server_plugin.dart';
import 'package:<project>_lints/rules/feature_imports_classifier.dart';

/// Brief description of what the rule enforces.
class MyNewRule extends DartLintRule {
  const MyNewRule() : super(code: _code);

  static const _code = LintCode(
    name: 'my_rule_name',
    problemMessage: 'What is wrong (shown to the developer).',
    correctionMessage: 'How to fix it.',
  );

  static const _classifier = FeatureImportsClassifier();

  @override
  List<String> get filesToAnalyze => const ['**/lib/features/**.dart'];

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final sourceLocation =
        _classifier.classify(resolver.source.uri.toString());

    // Guard: skip files outside the target scope.
    if (!sourceLocation.isFeatureFile) return;

    // Register the appropriate AST visitor.
    context.registry.addCompilationUnit((CompilationUnit unit) {
      // Analysis logic here...
      // reporter.atNode(node, _code);
    });
  }
}
```

### Step 2 — Register the rule

Add import + instantiation in `<project>_lints/lib/<project>_lints.dart`:

```dart
import 'package:<project>_lints/rules/my_new_rule.dart';

// Inside getLintRules:
const MyNewRule(),
```

### Step 3 — Create the test

Create `<project>_lints/test/rules/<rule_name>_rule_test.dart`:

```dart
import 'package:<project>_lints/rules/my_new_rule.dart';
import 'package:test/test.dart';

void main() {
  group('MyNewRule', () {
    test('code name is correct', () {
      const rule = MyNewRule();
      expect(rule.code.name, 'my_rule_name');
    });

    test('filesToAnalyze targets correct scope', () {
      const rule = MyNewRule();
      expect(
        rule.filesToAnalyze,
        contains('**/lib/features/**.dart'),
      );
    });
  });
}
```

If the rule has extractable pure logic (like `isForbiddenEdge`), expose it as a `@visibleForTesting` static method and add unit tests for it.

### Step 4 — Run tests

```bash
cd <project>_lints && dart test
```

### Step 5 — Verify against the codebase

```bash
cd <workspace_root> && dart analyze 2>&1 | grep "my_rule_name"
```

Count violations and spot-check 2–3 flagged files to confirm:
- True positives are actually violations
- Known valid files are NOT flagged (exemptions work)

## Key reference: FeatureImportsClassifier

Reuse the shared classifier to determine where a file lives in the architecture:

```dart
final location = _classifier.classify(resolver.source.uri.toString());

location.topLevelArea   // TopLevelArea.feature | .core | .routing | .other
location.featureName    // e.g. 'checkout', 'cart'
location.layer          // FeatureLayer.presentation | .domain | .data
location.subfolder      // FeatureSubfolder.widgets | .screens | .viewModels | ...
location.isFeatureFile  // true if topLevelArea == feature
```

## Key reference: AST registry methods

| Method | Use when |
|--------|----------|
| `addImportDirective((ImportDirective node) {...})` | Checking imports |
| `addClassDeclaration((ClassDeclaration node) {...})` | Checking individual classes |
| `addCompilationUnit((CompilationUnit unit) {...})` | Checking file-level properties (all classes, all imports) |
| `addMethodDeclaration((MethodDeclaration node) {...})` | Checking methods |

### Useful ClassDeclaration properties

```dart
node.name.lexeme                              // Class name (e.g. 'MyWidget')
node.extendsClause?.superclass.name.lexeme   // Superclass name (e.g. 'StatelessWidget')
node.abstractKeyword != null                  // Is abstract?
node.sealedKeyword != null                    // Is sealed?
node.name.lexeme.startsWith('_')              // Is private?
```

### Useful CompilationUnit properties

```dart
unit.declarations                             // All top-level declarations
unit.declarations.whereType<ClassDeclaration>() // All classes
unit.directives.whereType<ImportDirective>()   // All imports
```

## Severity

Default severity is `INFO`. To set `ERROR`:

```dart
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;

static const _code = LintCode(
  name: 'rule_name',
  problemMessage: '...',
  correctionMessage: '...',
  errorSeverity: DiagnosticSeverity.ERROR,
);
```

**Important:** Import `DiagnosticSeverity` with a `show` to avoid the `LintCode` name collision:
```dart
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
```

## Critical: glob patterns

All `filesToAnalyze` globs **must** start with `**/` to work in the Dart workspace setup:

```dart
// CORRECT — works in workspace
'**/lib/features/**.dart'

// WRONG — fails silently, matches nothing
'lib/features/**.dart'
```

## Running lint rules

Lint rules run natively through `dart analyze` from the **workspace root**:

```bash
cd <workspace_root> && dart analyze
```

## Checklist

- [ ] Rule file created in `<project>_lints/lib/rules/`
- [ ] Rule registered in `<project>_lints/lib/<project>_lints.dart`
- [ ] Test file created in `<project>_lints/test/rules/`
- [ ] `filesToAnalyze` glob starts with `**/`
- [ ] `dart test` passes in `<project>_lints/`
- [ ] `dart analyze` from workspace root finds expected violations
- [ ] Spot-checked 2–3 true positives and 2–3 correctly exempted files
