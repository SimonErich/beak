# Theming basics

> Give the panel a light and a dark theme from one brand color, choose the starting mode, and read theme tokens in your own widgets.

You set the theme once, on the panel, and every table, form, block and dialog reads it. After this page you can theme a panel from a single brand color, pick the mode it starts in, wire a theme into a generated panel, and read the theme from a widget of your own.

## At a glance

| Knob | Where | Default |
| --- | --- | --- |
| `theme`, `darkTheme` | `BeakPanel`, `BeakPanelConfig` | `OiThemeData.light()` and `OiThemeData.dark()` |
| `initialThemeMode` | `BeakPanelConfig` only | `OiThemeMode.system` |
| Theme toggle in the shell | `BeakNavigation.showThemeToggle` | shown |
| `sidebarCollapsible`, `sidebarDefaultCollapsed` | `BeakPanelConfig`, or `theme.sidebar` in `beak.yaml` | `true`, `false` |
| Locale, number, date and currency format | [Formatting and localization](formatting-and-localization.md) | English, `en_US`, `USD` |

`OiThemeData` is the obers_ui theme object: colors, type ramp, spacing, radii, shadows, motion and per-component styles in one immutable value. Beak has no theme type of its own, so everything you learn about `OiThemeData` in the obers_ui documentation applies as written.

## One brand color

`OiThemeData.fromBrand` builds a theme from a single color. The Aviary passes one color for light and a lighter one for dark, because a dark surface needs a brighter accent to read as the same brand:

```dart title="examples/showcase/lib/main.dart"
theme: OiThemeData.fromBrand(color: const Color(0xFF2F7D6B)),
darkTheme: OiThemeData.fromBrand(
  color: const Color(0xFF7FC4B2),
  brightness: Brightness.dark,
),
```

That is the whole change to the panel. The shop does the same in its `main.dart` with a blue:

```dart title="examples/clean_beak_config/lib/main.dart"
void main() => runApp(
  BeakPanel(
    title: 'Clean Beak Shop',
    theme: OiThemeData.fromBrand(color: const Color(0xFF315D91)),
    darkTheme: OiThemeData.fromBrand(
      color: const Color(0xFF82ACDF),
      brightness: Brightness.dark,
    ),
    locale: const Locale('en'),
    formatting: const BeakFormatting(
      locale: 'de_AT',
      currency: 'EUR',
      datePattern: 'dd.MM.yyyy',
      dateTimePattern: 'dd.MM.yyyy HH:mm',
    ),
    pages: [shopOverview(), shopOperations()],
    resources: [
      OrderResource(),
      InvoiceResource(),
      VoucherResource(),
      ProductResource(),
      VariantResource(),
      CategoryResource(),
      UserResource(),
      CompanyResource(),
      ProfileResource(),
      TaxRateResource(),
      FulfillmentPolicyResource(),
    ],
  ),
);
```

Read `fromBrand` for what it is. It replaces the primary swatch and the focus color and leaves everything else at the light or dark default. Success, warning, error, info and the neutral surfaces do not follow your brand, which is usually right for status colors. When they should, or when a design system dictates every color, build the theme by hand ([Colors and tokens](colors-and-tokens.md)).

`OiThemeData.light()` and `.dark()` also take a `fontFamily`, a `monoFontFamily` and a `radiusPreference` (`sharp`, `medium` or `rounded`). Those three are the cheapest way to change how a panel feels without touching a color. `fromBrand` takes the same arguments.

## Where the theme goes

**Authored panel.** Pass the themes to `BeakPanel(theme:, darkTheme:)`, as above. When you build a `BeakPanelConfig` yourself, the same names are fields on it, plus `initialThemeMode`.

**Generated panel.** `lib/main.dart` is a single `runApp(const BeakApp())` and `beak prepare` writes the config. Take over the theme with the `theme` ejection:

```console
$ beak eject theme
  created lib/theme.dart

  run `beak prepare` to wire it up
$ beak prepare
  1 model · 0 resource classes · 0 screens · 1 override
  generated  1 of 8 files
```

```dart title="lib/theme.dart"
import 'package:beak/ui.dart';

/// The theme the panel uses in light mode.
OiThemeData beakLightTheme() => OiThemeData.light();

/// The theme the panel uses in dark mode.
OiThemeData beakDarkTheme() => OiThemeData.dark();
```

`beak prepare` finds `lib/theme.dart` by its `beakLightTheme` function and writes `theme: theme.beakLightTheme()` and `darkTheme: theme.beakDarkTheme()` into `lib/beak/panel.g.dart`. Declare both functions. The generated code calls both, so a file with only the light one does not compile. Edit the bodies to `fromBrand` or to a full theme, then run `beak prepare` again if you added or removed the file.

The other settings the generated panel needs, such as formatting and the starting mode, go in `lib/panel.dart` (`beak eject panel`), which receives the generated `BeakPanelConfig` and returns the one to use:

```dart title="lib/panel.dart"
import 'package:beak/panel.dart';

/// The last word on this panel's configuration.
///
/// [defaults] is everything `beak.yaml`, the models, the resource classes and
/// `lib/screens/` produced. Return it to change nothing, or `copyWith` the
/// parts you want different: the resources list, the notification source.
BeakPanelConfig beakPanel(BeakPanelConfig defaults) => defaults;
```

For example, `defaults.copyWith(initialThemeMode: OiThemeMode.dark)`. The sidebar switches have a `beak.yaml` form too: `theme.sidebar.collapsible` and `theme.sidebar.startCollapsed`.

## Light, dark and the toggle

The panel builds one `OiApp` with both themes and a mode. `OiThemeMode.system` follows the operating system, `light` and `dark` pin it. The shell shows a toggle (`OiThemeToggle`) that changes the mode live, without rebuilding the router or losing the page you are on. Switch it off with `BeakNavigation.showThemeToggle: false` when the panel should not offer the choice.

The chosen mode is not saved. A reload goes back to `initialThemeMode`, so set that if your users all want dark. Custom widgets can read and change the mode through the panel's `BeakThemeController`, a `ValueNotifier<OiThemeMode>`:

```dart title="packages/beak_frontend/lib/src/panel/beak_theme_controller.dart"
final class BeakThemeController extends ValueNotifier<OiThemeMode> {
  /// Creates a controller starting in the given mode (default: system).
  BeakThemeController([super.initialMode = OiThemeMode.system]);
}

```

## Reading the theme in your own widgets

Colors, spacing and radii are extensions on `BuildContext`: `context.colors`, `context.spacing`, `context.radius`, and `context.components` for per-component styles. A custom widget that uses them follows the theme and flips with the toggle. Beak's own blocks resolve their semantic colors this way:

```dart title="packages/beak_frontend/lib/src/blocks/views/beak_record_readers.dart"
Color? _resolveBeakColor(BuildContext context, BeakColor? color) {
  final colors = context.colors;
  return switch (color) {
    null => null,
    BeakColor.primary => colors.primary.base,
    BeakColor.secondary => colors.accent.base,
    BeakColor.success => colors.success.base,
    BeakColor.warning => colors.warning.base,
    BeakColor.error => colors.error.base,
    BeakColor.info => colors.info.base,
    BeakColor.muted => colors.textMuted,
  };
}
```

The same idea in a widget of your own (illustrative; the names are real):

```dart
BeakWidgetBlock(
  (context) => OiLabel.small(
    'Last synced 5 minutes ago',
    color: context.colors.textMuted,
  ),
)
```

A hex value in a widget keeps its color in dark mode, and the toggle test below is how you find it.

## Rules and limits

- **Both themes, or the default.** A missing `theme` is `OiThemeData.light()`, a missing `darkTheme` is `OiThemeData.dark()`. A panel that sets only `theme` gets Beak's stock dark theme in dark mode, not a dark version of yours.
- **The mode is not persisted.** A reload restores `initialThemeMode`.
- **`BeakPanel(...)` does not take `initialThemeMode`.** The shorthand has `theme` and `darkTheme` only. For the mode, the sidebar flags, `supportedLocales` and `localizationsDelegates`, build a `BeakPanelConfig`.
- **No Material.** A Beak panel imports neither `material.dart` nor `cupertino.dart`. `OiApp` provides what those would have. Do not wrap a panel in a Material `Theme`.

## Verify it

The generated path is checked by running the two commands above in a project: `lib/beak/panel.g.dart` then contains `import '../theme.dart' as theme;` and the two `theme:` lines. For the authored path, the Aviary's page tests build the panel with its brand themes:

```console
$ cd examples/showcase
$ flutter test --no-pub test/aviary_pages_test.dart
...
00:05 +12: All tests passed!
```

Run either panel and press the theme toggle in the top bar. Every surface should change together. A color that stays put is hard-coded somewhere.

## Reference

| Symbol | What it is |
| --- | --- |
| `OiThemeData.light`, `.dark` | The stock themes. Take `fontFamily`, `monoFontFamily`, `radiusPreference`, `components`, `breakpoints`. |
| `OiThemeData.fromBrand(color:, brightness:)` | A stock theme with a new primary swatch and focus color. |
| `OiThemeData.copyWith` | Replace any part: `colors`, `textTheme`, `radius`, `shadows`, `components` and more. |
| `OiThemeMode` | `light`, `dark`, `system`. |
| `BeakPanelConfig.theme`, `.darkTheme`, `.initialThemeMode` | Where the panel takes them. |
| `BeakThemeController` | The panel's live mode, registered in its dependency scope. |
| `BeakNavigation.showThemeToggle` | Whether the shell shows the toggle. |

## Continue reading

- [Colors and tokens](colors-and-tokens.md) build a full theme and see how `BeakColor` becomes a color.
- [Typography and icons](typography-and-icons.md) the type ramp and the icon set a theme can re-skin.
- [Formatting and localization](formatting-and-localization.md) dates, numbers, currency and the UI language.
- [Foodio](../examples/foodio.md) a complete custom theme in a real panel.
