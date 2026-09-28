# Prototype fidelity and reusable presentation contracts

The reference is `food-ordering-shop.html` at the repository root. Foodio uses
Beak and the local **Obers UI** package. No Fluvie package is used by this app.
`lib/theme/gabel_theme.dart` owns typography, surfaces, geometry and interaction
colors; resources own their declarative composition and business content.

## Why the earlier rendering differed

- Navigation hover incorrectly reused the selected foreground without its
  selected background. Dark icons became invisible on the dark rail.
- Framed custom pages and generated record pages painted a card around content
  that already declared cards, leaving an unwanted white slab between them.
- The theme supplied a fixed variable-font `wght` axis even for ordinary
  hundred-step weights. Component `fontWeight` overrides could not change it.
- An opaque layout border replaced the reference's translucent outside shadow,
  shifting every card's content by one pixel. The table also bypassed card tokens.
- Button padding and variant hover/pressed colors were declared in themes but
  ignored by the renderer. Ghost buttons changed weight and icon size on hover,
  shifting content. The shared renderer now uses the existing tokens and keeps
  geometry stable.
- Compact table controls inherited ordinary form dimensions. Pagination applied
  its size token inconsistently to page numbers, arrows and the page-size selector.
- Charts forced small label fonts and their axis painter discarded the font
  family. The overview configured the primary color instead of the chart palette.
- Wizard titles scrolled away with the fields. Read-only collections reused
  editing presentation, introducing redundant headers, controls and spacing.

## Contracts used by the example

**Surfaces.** Page and row/grid layouts provide structure. Cards own their fill,
radius and elevation. Gabel uses no layout border and the reference's three
shadows: a translucent one-pixel outside edge, a small contact shadow, and a
subtle wider shadow. Headerless `OiCard` forwards bounded constraints, so a table
or scrollable can use available height. `headerGap` separates a card heading
from its content without requiring an application spacer widget.
The gap collapses with a collapsible card's body. An underline tab divider
occupies layout space independently of its controls, matching the reference's
44px controls plus 1px separator.

**States.** Navigation selection and hover have independent theme tokens.
Selected foreground/background pairs stay together. Radio indicators and radio
tiles use component themes; selection borders paint without moving content.
Labels remain accessible when segmented controls show icons only. Chart/table
switches use `OiSegmentedControl(showLabels: false)` and expose selection state.
Sortable table headings retain their themed size and weight on hover. Record
actions use `roles` to declare where they appear; live Edit/Cancel transitions
update those actions without rebuilding an application-specific header.

**Typography.** Ordinary weights use `TextStyle.fontWeight`; only fractional
weights such as 560/580 need a `wght` variation. The width axis remains explicit.
Metadata uses the caption role (12/16, weight 500, tracking 0.12 in Gabel),
normal body copy remains 14/20, and section headings use the heading roles.
Chart axes honor `components.chart.axis` and plot insets honor
`components.chart.density.padding`. Donut value legends use `OiChartLegend(valueList: true)`, with independent
`valueLabelStyle`, `valueStyle` and `valueSpacing` tokens. Compact inline legends
keep their own density. `centerValueStyle` controls a radial chart's primary
number. Cartesian categories can be `emphasized` without labelling every bar;
`density.barWidth` and `sectionSpacing` keep sectioned charts aligned, and the
same geometry drives paint and pointer hit testing. Grid dash patterns and
widths now reach the bar painter.
Compact table identities configure `textGap: 0`, a 12px avatar gap and medium
name emphasis through existing record-template bindings.
Bindings can choose `textOverflow` when a known short value should retain the
HTML reference's natural overflow; other single-line metadata still truncates.
Per-record `tone` preserves warning/error information in delivery and payment
metadata. Avatar tones and their dependencies are declared alongside identity
bindings, so relationship loading remains automatic.

**Density.** Table toolbars and row actions use the small component size;
ordinary forms retain their medium size. Pagination applies `buttonSize` to
arrows and the page-size selector as well as numbered pages. Larger page
numbers can still grow without truncation.
Solid choice facets use 12px padding, 16px checks and tabular numerals; dashed
filter triggers keep their own compact presentation. Capacity ratios also use
tabular numerals. Capacity summary rows have natural 16px gaps rather than
distributing spare height into changing row positions.

**Composition.** `BeakRowBlock(expand: true)` allocates available width by the
children's `span.columns` weights after subtracting actual gaps, then stacks
when a child would become too narrow. A track grid remains available when
alignment across multiple rows is intended. Wizard steps declare `heading`
and `introduction` separately from their navigation labels. The shared wizard
pins that header above independently scrolling fields and retains access to
content in short windows.

**Shell.** The app supplies workspace/resource configuration. Beak creates the
workspace title and authorized create action with `OiSidebarHeader`. The desktop
search control is an accessible `OiSearchTrigger`, with the real input inside
the search overlay. Header action spacing and search geometry are theme tokens;
the example no longer builds a custom workspace header. Notification counters
and compact allergen tokens have independent badge metrics.
Long titles and breadcrumbs consume the remaining header width, keeping the
search and account controls visible without changing the Orders header geometry.

**Interactive colors.** `OiTappable.statesController` exposes pointer/focus/press
state to components without duplicating gesture handling. Buttons resolve the
configured variant colors and preserve font weight/icon size across states.
`applyBackgroundOverlay: false` permits an explicit component state color while
retaining keyboard focus rings. Button padding is honored for all sizes;
component defaults remain available when no override is supplied.

**Chart semantics.** The status chart describes active orders, excluding
cancelled records; its center and legend are calculated from the same measures.
The prototype's static aggregates are not all consistent with its visible rows.
Operational totals remain calculated from the seeded records instead of copying
contradictory numbers into the UI. An unresolved redelivery is scheduled for the
operating date with no assigned slot, and its note records the earlier failure.

## Verification

The visual audit measures the ten supplied states at their reference viewports
and inspects actual screenshots. Hover checks count painted contrast pixels,
surface checks sample the gaps between cards, and font tests load the real
variable font. Widget tests cover bounded layout, state changes, keyboard
interaction, responsive stacking and wizard scrolling. Browser scripts repeat
list/filter and preview-only wizard flows without writing orders.

See [VERIFICATION.md](VERIFICATION.md) for the latest runs and evidence. Compare
matching scroll, focus, hover and selection states; a screenshot alone does not
establish that interactive styling is correct. Reference mock totals and IDs
must not replace authoritative prices, capacity, approval state or identifiers
assigned only on save.

## Recurring delivery preferences and pending reads

Profiles declare nullable `preferredDeliveryStart` / `preferredDeliveryEnd`
`BeakTime` values. A profile preference repeats across dates; it does not refer
to one dated capacity slot. The slot input queries the chosen date and location
method, then resolves that preference only among loaded eligible options with
`defaultOptionMatch` and `selectDefaultOption`. A valid manual selection remains
in place. Query changes invalidate incompatible choices and stale responses
cannot restore them. The capacity overview explicitly queries office delivery.
The demo private preference has a real Tuesday 18:00–18:30 home slot, leaving
Monday's five office filters and capacity rows unchanged.

Form sessions use `BeakResourceRepository.coalescing` to share identical pending
queries. Completed results are never cached, and mutation notifications clear
pending join eligibility. Record permissions remain record-specific. This is a
bounded request reduction; it does not claim that every repeated request in an
edit workflow is unnecessary.

Gabel supplies semantic default/focus/error decoration colors together with its
palette; `OiThemeData.copyWith` preserves independent explicit decoration and
component overrides. The public construction recipe is documented in Obers'
[Extending Themes](../../../obers_ui/doc/documentation/docs/theming/extending-themes.md).
Labelled date presets share the theme's 500 weight and 2px gaps. Distributed
pagination uses natural group widths and equal free space rather than equal
left/right columns; wide pages retain the reference's natural alignment.


## Pending edit presentation

The order edit layout opts into `showChangeIndicators`. Beak compares readable,
editable scalar values and relationship foreign keys against their existing
draft baseline. The shared `OiFieldLabel` displays the themed marker and an
accessible Modified description. Inline internal-note arguments inherit the
persisted order's context; new compact item rows use their existing unsaved-row
state. Restoring a field, discarding the draft or removing a pending row clears
its marker. Creation and read-only views retain their ordinary headings.

Quantity controls accept a declarative `controlWidth` through the same bound
value input, allowing the edit list's 90px selector without a custom renderer.


Relationship choices use `inputCards(cardPadding: ...)` for a measured content
inset while retaining the shared radio-card selection and outline geometry.
Scalar choice cards use their separate card-padding override. Field-like radio
headings opt into `groupLabelAsField`; payment section headings keep their own
radio typography and 12px heading gap, independent of 8px between options.
Capacity labels and values now declare separate styles, preserving 12/16 labels
and 14/20 balance values without changing stored amounts or progress state.


Compact button icon gaps use `OiButtonThemeData.smallIconGap: 6`; ordinary
controls retain the 8px global gap. The prototype's compact toolbar buttons
were 2px narrower each, shifting the right-aligned pair by 4px. The size-specific
token corrects that measured box-model cause without changing font weights.

Regular icon-and-label actions use semantic `iconLabelPadding` with 12px on the
icon side and 14px on the label side; trailing icons reverse those insets.
Compact buttons retain 12px insets. This corrects the independently measured
header action widths while preserving existing defaults for themes that omit
the token. A placement-specific multiline inset keeps the delivery comment at
58px while ordinary two-line notes retain 64px.

Catalog category tones come from declared dish category/diet values. Gabel's
`catalogVegetableSoft` and `catalogDessertSoft` are the prototype's 26% chart/sheet
mixes in OKLCH, resolved by Chrome: light #CDDCEC/#DDD8EC and dark #202D3B/#322D3E.
They preserve the reference color-space mixing rather than replacing it with
an RGB alpha blend. These are category presentation roles, not per-record
manual color assignments.

Inline catalog extras declare `advancedContentPadding` with 12px horizontal and
10px vertical insets. Their 15px separation belongs to visible advanced content,
so collapsed panels contribute no hidden height. The ordinary inline surface
retains its 12px default, and dialog row layouts are unaffected.


## List and navigation scroll roles

Orders declares `BeakListScrollMode.page`: the existing shared table sizes to
its loaded rows, and the shared page body scrolls through pagination. At 1000px
height this leaves later rows and pagination below the viewport, matching the
reference's page structure. Other lists retain the bounded table default.
Compact page lists scroll their heading with the content, retaining room to
reach rows and pagination.

The current record uses the shared contextual branch presentation. Order
identifiers opt into the code text role in navigation and breadcrumbs; ordinary
names keep body typography. Breadcrumb links use Gabel's plain muted role and
retain a stable weight on hover. A themed 16px chevron and 8px separator insets
replace the hardcoded slash, preserving the reference 32px label separation.
Ordinary expandable destination groups keep
their existing icons and indentation.

Chart axes declare `labelGap: 8`, replacing the previous hardcoded 4px numeric
gap while preserving omitted-theme defaults. Floating pending-change surfaces
use the existing `shadows.lg` role with the reference's ring, contact and ambient
layers; card shadows retain their separate role. Radio cards use a dedicated
14/20 weight 500 title role, while ordinary radio labels retain weight 400.


The numeric review total uses `gabelNumericTotalStyle`: the existing heading 2
22/28 weight 580, width 106 and −.22px tracking, with tabular numbers added. This
keeps total widths stable when only digits change; ordinary summary values keep
their own roles. A loaded-font layout regression checks equal widths for €41.31
and €48.60 against the prototype's 77.6875px text run.
