---
name: uikit
scope: flutter
description: Reference for creating, extending, or modifying the `uikit` abstraction layer itself. Use when wrapping `obers_ui`, adding exports under `<project>_flutter/lib/uikit/`, or answering architecture questions about that layer. Do not use this for ordinary feature UI work; use `create-visual-ui` instead.
role: reference
trigger: direct_match
pairs_with:
  - create-visual-ui
---

# UIKit — Widget Abstraction Layer

This skill is reference material for the UIKit abstraction layer. It should not compete with ordinary feature UI workflows.

## Architecture

```
Feature code  →  uikit (abstraction)  →  obers_ui (external library)
```

- **Feature code** imports only `uikit/uikit.dart` — never `obers_ui` directly
- **uikit** wraps obers_ui primitives with project-specific API, design tokens, and accessibility
- **obers_ui** is the external widget library — only imported via `_obers_imports.dart`

### Import Barrier

All obers_ui imports flow through a single file:

```
<project>_flutter/lib/uikit/_obers_imports.dart
```

Every file inside `uikit/` imports obers_ui ONLY through `_obers_imports.dart`. This ensures that swapping the underlying library requires changing only one file.

## Before You Start

**ALWAYS read `OBERS_UI_LIBRARY_AI_DOCS.md`** (project root) before creating or extending a widget. It documents:

- All available obers_ui primitives, components, composites, and modules
- Tier hierarchy: Foundation → Primitives → Components → Composites → Modules
- Which widgets are implemented vs `[PLANNED]`
- Correct parameter names and constructor variants

**ALWAYS read `docs/accessibility_contract.md`** when changing interactive UIKit behavior. UIKit work must satisfy the repo's accessibility contract.

Key requirements to remember:

- Interactive targets must meet the minimum touch target size.
- Icon-only controls need a non-null semantic label.
- Modal content must use `UiFocusTrap`.
- Do not rely on semantic status colors alone for text on white backgrounds.

## Directory Structure

```
lib/uikit/
  _obers_imports.dart       # Single import point for obers_ui
  uikit.dart                # Barrel file — all public exports
  components/               # Core primitives: UiButton, UiCard, UiText, UiInputs, etc.
  widgets/                  # Domain-aware composed widgets: UiGuestRow, UiEmptyState, etc.
  layouts/                  # Shell and navigation: UiScaffold, UiAppShell, UiNavigationRail
  theme/                    # Design tokens, theme factory, responsive breakpoints
  utils/                    # Icons, formatters, accessibility helpers, calendar helpers
  overwrite/                # Whitelabel override registry (REQ-0173)
```

### components/ vs widgets/

| Folder | Purpose | Example |
|--------|---------|---------|
| `components/` | Thin wrappers around a single obers_ui widget. Stable API surface. | `UiButton`, `UiCard`, `UiText`, `UiCheckbox` |
| `widgets/` | Composed from multiple components. May contain domain logic (e.g., cart empty state). | `UiGuestRow`, `UiEmptyState`, `UiFilterBar` |

## Creating a New Component (wrapping obers_ui)

Use this when obers_ui provides a primitive that your project needs to expose.

### Steps

1. **Check `OBERS_UI_LIBRARY_AI_DOCS.md`** — find the obers_ui widget and note its constructors and parameters.
2. **Create file** in `components/` named `ui_<name>.dart`.
3. **Import only through `_obers_imports.dart`**:
   ```dart
   import 'package:<project>_flutter/uikit/_obers_imports.dart';
   ```
4. **Map the public API** — expose project-named constructors that delegate to the obers_ui widget.
5. **Add to barrel file** — export the new file from `uikit.dart`.

### Template

```dart
import 'package:flutter/widgets.dart';
import 'package:<project>_flutter/uikit/_obers_imports.dart';
import 'package:<project>_flutter/uikit/theme/ui_design_tokens.dart';

/// Brief description of what this component wraps.
///
/// Wraps [OiSomething] from obers_ui.
class UiSomething extends StatelessWidget {
  const UiSomething({
    required this.label,
    super.key,
    this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: OiSomething(
        label: label,
        onTap: onPressed,
      ),
    );
  }
}
```

## Creating a New Widget (composed from components)

Use this when you need a domain-aware, multi-component widget.

### Steps

1. **Check existing widgets** — search `uikit.dart` exports before creating duplicates.
2. **Check `OBERS_UI_LIBRARY_AI_DOCS.md`** — obers_ui may have a composite or module that covers the use case.
3. **Create file** in `widgets/` named `ui_<name>.dart`.
4. **Import uikit components**, not obers_ui directly (except through `_obers_imports.dart` for types like OiIcons).
5. **Use design tokens** from `theme/ui_design_tokens.dart` for all spacing, colors, typography.
6. **Extract sub-widgets** — keep the main widget under 300 lines; use private `_SubWidget` classes.
7. **Add to barrel file** — export from `uikit.dart`.

### Template

```dart
import 'package:flutter/widgets.dart';
import 'package:<project>_flutter/uikit/_obers_imports.dart';
import 'package:<project>_flutter/uikit/components/ui_button.dart';
import 'package:<project>_flutter/uikit/components/ui_text.dart';
import 'package:<project>_flutter/uikit/theme/ui_design_tokens.dart';

/// A widget that displays [describe purpose].
class UiFeatureCard extends StatelessWidget {
  const UiFeatureCard({
    required this.title,
    required this.description,
    super.key,
    this.onAction,
  });

  final String title;
  final String description;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(UiDesignSpacing.md),
      decoration: BoxDecoration(
        color: UiDesignColors.card,
        borderRadius: UiDesignRadius.panel,
        border: Border.all(color: UiDesignColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(title: title),
          const SizedBox(height: UiDesignSpacing.sm),
          UiText.body(description, color: UiDesignColors.textSecondary),
          if (onAction != null) ...[
            const SizedBox(height: UiDesignSpacing.md),
            UiButton.primary(label: 'Action', onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

/// Private sub-widget — keeps the main build method clean.
class _Header extends StatelessWidget {
  const _Header({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return UiText.h3(title);
  }
}
```

## When obers_ui Does Not Have What You Need

1. **Build from obers_ui primitives** — use `OiRow`, `OiColumn`, `OiCard`, etc. as building blocks.
2. **Use design tokens** — never hardcode colors, spacing, or typography.
3. **Use `Container` / `DecoratedBox`** sparingly for custom layouts, always with `UiDesignColors` and `UiDesignRadius`.
4. **Do NOT import Material or Cupertino** — use `flutter/widgets.dart` only.
5. **Add a TODO** in the widget's doc comment explaining what obers_ui element is needed:
   ```dart
   // TODO(obers_ui): Create OiTimePicker primitive — needs hour/minute wheels,
   // AM/PM toggle, optional 24h mode, and OiThemeData integration.
   // Until then, this widget uses a custom implementation.
   ```

## Widget Size Rules

- **Maximum 300 lines per file** — if a widget exceeds this, extract sub-widgets.
- **One public widget per file** — private helpers (`_SubWidget`) share the file.
- **Extract when build() exceeds ~50 lines** — move logical sections into private widgets.
- **Prefer composition** — small widgets composed together, not deeply nested trees.

## Design Token Usage

```dart
import 'package:<project>_flutter/uikit/theme/ui_design_tokens.dart';

// Spacing
UiDesignSpacing.xxs  // 2.0
UiDesignSpacing.xs   // 4.0
UiDesignSpacing.sm   // 8.0
UiDesignSpacing.md   // 16.0
UiDesignSpacing.lg   // 24.0
UiDesignSpacing.xl   // 32.0

// Colors
UiDesignColors.primary
UiDesignColors.textPrimary
UiDesignColors.textSecondary
UiDesignColors.textTertiary
UiDesignColors.border
UiDesignColors.card
UiDesignColors.cardHover
UiDesignColors.background
UiDesignColors.error
UiDesignColors.success
UiDesignColors.warning

// Typography
UiDesignTypography.h1 / h2 / h3
UiDesignTypography.body
UiDesignTypography.small / smallMedium
UiDesignTypography.button

// Border radius
UiDesignRadius.small / panel / card
```

## Overwrite System (Whitelabel)

The `overwrite/` folder contains an `OverwriteRegistry` singleton that allows whitelabel clients to replace default widgets:

```dart
OverwriteRegistry.instance.register('UiButton', (context) => CustomButton());
```

Components can check for overrides using `OverwriteRegistry.instance.resolve(...)`.

## Checklist

- [ ] Read `OBERS_UI_LIBRARY_AI_DOCS.md` for existing obers_ui primitives
- [ ] Read `docs/accessibility_contract.md` when changing interactive UIKit behavior
- [ ] Widget file is under 300 lines
- [ ] Sub-widgets extracted for sections longer than ~50 lines of build code
- [ ] Only one public widget class per file
- [ ] Imports obers_ui only through `_obers_imports.dart` (never direct `package:obers_ui/`)
- [ ] Uses `UiDesignColors`, `UiDesignSpacing`, `UiDesignTypography` — no hardcoded values
- [ ] Accessibility: `Semantics` wrapper or `semanticLabel` on interactive elements
- [ ] Added export line to `uikit.dart` barrel file
- [ ] No Material or Cupertino widget imports in the file
- [ ] Run `flutter test test/uikit/accessibility/accessibility_contract_test.dart` for UIKit contract changes
