---
name: create-visual-ui
description: Mandatory guardrail companion for user-facing Flutter feature UI such as screens, forms, dialogs, lists, and cards. Enforces UIKit usage, accessibility, and design-token rules. Pair with `flutter-add-screen` or `flutter-add-widget`, and use `uikit` only when editing the `uikit` layer itself.
role: guardrail
scope: flutter
trigger: auto_with_workflow
pairs_with:
  - flutter-add-screen
  - flutter-add-widget
  - flutter-widget-composition
---

# Create Visual UI — Mandatory Rules

This is the main Flutter feature UI guardrail companion. Read it before executing the primary UI workflow; do not use it as the sole task owner when a more specific workflow skill applies.

## Pre-Flight (BEFORE writing any code)

### Step 1: Read OBERS_UI_LIBRARY_AI_DOCS.md

Always read `OBERS_UI_LIBRARY_AI_DOCS.md` first to understand available obers_ui primitives.

### Step 2: Check Existing uikit Widgets

Read the barrel file `<project>_flutter/lib/uikit/uikit.dart`.

Search for widgets matching your use case before creating new ones.

### Step 3: Check Design Tokens

Read `<project>_flutter/lib/uikit/theme/ui_design_tokens.dart`.

### Step 4: Clarify The Right Companion Skill

- Use `flutter-widget-composition` when the main risk is file size, widget extraction, or rebuild scope.
- Use `uikit` only when changing files inside `<project>_flutter/lib/uikit/`.

## Absolute Rules — ZERO EXCEPTIONS

### Rule 1: NO Material Design Widgets

NEVER import or use:

```dart
// FORBIDDEN in feature code
import 'package:flutter/material.dart';

// FORBIDDEN widgets (partial list):
ElevatedButton, TextButton, OutlinedButton, FloatingActionButton,
Text, Card, TextField, TextFormField, Scaffold, AppBar,
Dialog, BottomSheet, CircularProgressIndicator, Checkbox,
Switch, Chip, TabBar, Divider, ListTile, SnackBar, Tooltip,
PopupMenuButton, DropdownButton, Slider, Radio, Badge
```

ONLY allowed Flutter imports in feature code:
```dart
import 'package:flutter/widgets.dart';       // Base widgets
import 'package:flutter/services.dart';       // Keyboard, clipboard
import 'package:flutter/foundation.dart';     // Annotations
```

### Rule 2: NO Direct obers_ui Imports

```dart
// FORBIDDEN in feature code
import 'package:obers_ui/obers_ui.dart';

// CORRECT — always through uikit barrel
import 'package:<project>_flutter/uikit/uikit.dart';
```

### Rule 3: Design Tokens for ALL Visual Properties

```dart
// FORBIDDEN
padding: EdgeInsets.all(16),
color: Color(0xFF1A1A1A),

// CORRECT
padding: EdgeInsets.all(UiDesignSpacing.md),
color: UiDesignColors.primary,
```

Spacing: `UiDesignSpacing.xxs(2) / xs(4) / sm(8) / md(16) / lg(24) / xl(32)`

### Rule 4: Accessibility Contract (WCAG AA)

| Pillar | Requirement |
|--------|-------------|
| Touch Targets | >= 44 x 44 dp |
| Semantic Labels | All interactive elements |
| Focus Management | Modals wrapped in `UiFocusTrap` |
| Color Contrast | 4.5:1 text, 3.0:1 UI |

```dart
// Icon-only button — MUST have semanticLabel
UiIconButton(icon: UiIcons.close, semanticLabel: 'Close dialog', onPressed: close);

// Modal — MUST use UiFocusTrap
showDialog(
  context: context,
  builder: (_) => UiFocusTrap(
    onEscape: () => Navigator.pop(context),
    child: UiFormDialog(/* ... */),
  ),
);
```

## Widget-to-UIKit Mapping

| You need... | Use this |
|-------------|----------|
| Page shell | `UiScaffold` |
| Text | `UiText.h1()`, `.h2()`, `.body()`, `.small()` |
| Button | `UiButton.primary()`, `.secondary()`, `.ghost()`, `.destructive()` |
| Icon button | `UiIconButton` |
| Card | `UiCard` |
| Text input | `UiInputs.text()`, `.multiline()`, `.number()` |
| Checkbox | `UiCheckbox` |
| Switch | `UiSwitch` |
| Select / dropdown | `OiSelect` + `OiSelectOption` |
| Badge | `UiBadge` |
| Divider | `UiDivider` |
| Tab bar | `UiTabBar` |
| Data table | `UiDataTable` |
| List tile | `UiListTile` |
| Empty state | `UiEmptyState` |
| Loading | `UiLoadingState` / `UiSpinner` |
| Error state | `UiErrorState` |
| Toast | `UiToast` / `UiMicroToast` |
| Dialog | `UiFormDialog` / `UiConfirmDialog` |
| Sheet | `OiSheet` / `UiContextSheet` |
| Tooltip | `UiTooltip` |
| Progress | `UiProgressIndicator` |
| Avatar | `UiAvatar` / `UiInitialsAvatar` |

## Templates

### Screen

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get_it/get_it.dart';
import 'package:<project>_flutter/uikit/uikit.dart';

class FeatureScreen extends HookWidget {
  const FeatureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = GetIt.I<FeatureViewModel>();
    return UiScaffold(
      body: Watch((context) {
        if (vm.isLoading.value) return const UiLoadingState();
        if (vm.error.value != null) return UiErrorState(message: vm.error.value!);
        return _Content(data: vm.data.value);
      }),
    );
  }
}
```

## Post-Creation Verification

```bash
# Check for forbidden imports and obvious hardcoding
rg "package:flutter/material\.dart" <project>_flutter/lib/features/<FEATURE>/
rg "package:obers_ui/" <project>_flutter/lib/features/<FEATURE>/
rg "Color\(0x" <project>_flutter/lib/features/<FEATURE>/
rg --files <project>_flutter/lib/features/<FEATURE>/presentation
```

## Checklist

- [ ] Read `OBERS_UI_LIBRARY_AI_DOCS.md` BEFORE writing code
- [ ] Checked existing uikit widgets — no duplicates
- [ ] ZERO Material Design imports in feature code
- [ ] ZERO direct `obers_ui` imports in feature code
- [ ] ALL spacing/colors/typography use design tokens
- [ ] Widget file under 300 lines
- [ ] Sub-widgets extracted as classes (NOT functions)
- [ ] HookWidget used (NOT StatefulWidget)
- [ ] Interactive elements have semantic labels
- [ ] Touch targets >= 44 x 44 dp
- [ ] Modals wrapped in `UiFocusTrap`
