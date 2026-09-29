import 'beak_input_presentation.dart';
import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';

import 'beak_form_session.dart';
import '../formatting/beak_field_format.dart';
import '../presentation/beak_record_template.dart';

/// The presentation mode of a configured form.
enum BeakFormMode {
  /// Displays values without editing controls.
  read,

  /// Builds a new record draft.
  create,

  /// Edits an existing record draft.
  edit,
}

/// Navigation used by a configured wizard without changing its draft state.
enum BeakWizardNavigation {
  /// Compact progress text above the current step.
  inline,

  /// Responsive step rail with pinned actions and an optional summary aside.
  rail,
}

/// Presentation of the same automatically queried relationship options.
enum BeakRelationPresentation {
  /// A searchable dropdown.
  combobox,

  /// Search followed by inline record results.
  search,

  /// Rich selectable cards.
  cards,

  /// An exact code lookup with explicit Apply and Remove actions.
  code,
}

/// Why an option cannot currently be selected, or null when available.
typedef BeakOptionDisabledReason =
    String? Function(BeakRecord record, BeakFormReader state);

/// What removing a persisted related row means.
enum BeakRemoveBehavior {
  /// Removes relationship membership while retaining the related record.
  detach,

  /// Deletes a record only through an explicitly owned relationship.
  deleteOwned,
}

/// A predicate over the live, typed draft.
typedef BeakVisibility = bool Function(BeakFormReader state);

/// An additional synchronous or asynchronous field validation rule.
typedef BeakFieldValidator<T extends Object> =
    FutureOr<String?> Function(T? value, BeakFormReader state);

/// A pure node in a reusable form and detail layout.
abstract class BeakFormNode {
  /// Creates a layout node with an optional visibility condition.
  const BeakFormNode({this.visibleIf, this.enabledIf});

  /// Whether this node and its descendants are shown in the current draft.
  final BeakVisibility? visibleIf;

  /// Whether this node and its descendants accept edits in the current draft.
  final BeakVisibility? enabledIf;
}

/// A reusable tree of fields; the same tree supports read, create and edit.
class BeakFormLayout extends BeakFormNode {
  /// Creates a reusable, declarative layout.
  const BeakFormLayout({
    required this.children,
    this.spacingInPixels = 16,
    this.showChangeIndicators = false,
    super.visibleIf,
    super.enabledIf,
  });

  /// Vertical spacing for plain layouts and tab contents.
  final double spacingInPixels;

  /// Marks modified field headings and added owned rows while editing a
  /// persisted record. Markers use the existing draft baseline, not extra state.
  final bool showChangeIndicators;

  /// Ordered child nodes rendered in this layout.
  final List<BeakFormNode> children;

  /// Uses each model column's default input and model validation rules.
  factory BeakFormLayout.fromModel(
    BeakModel model, {
    BeakModelRegistry? registry,
  }) {
    final byKey = <String, BeakBelongsTo>{
      for (final relation in model.relationships)
        if (relation is BeakBelongsTo) relation.foreignKey: relation,
    };
    return BeakFormLayout(
      children: [
        for (final column in model.columnsFor(BeakContext.form))
          if (column.key != model.primaryKey.key && column is! BeakCustomColumn)
            if (byKey[column.key] case final BeakBelongsTo relation)
              if (registry?.byTable(relation.relatedTable)
                  case final BeakModel target)
                BeakRelationInput(
                  field: BeakToOneField(
                    model: model,
                    relation: relation,
                    target: target,
                  ),
                )
              else
                BeakInput<Object>(
                  field: BeakScalarField<Object>(model: model, column: column),
                )
            else
              BeakInput<Object>(
                field: BeakScalarField<Object>(model: model, column: column),
              ),
      ],
    );
  }
}

/// A quiet separator between groups without introducing a heading or surface.
final class BeakFormDivider extends BeakFormNode {
  /// The surrounding layout owns vertical spacing.
  const BeakFormDivider({super.visibleIf});
}

/// A responsive review row with a label and an optional wizard edit link.
/// Content uses the existing draft in read mode; returning to its source step
/// preserves the same fields, validation, and staged relationship changes.
class BeakReviewSection extends BeakFormLayout {
  /// Groups review content and optionally links back to its source step.
  const BeakReviewSection({
    required this.title,
    required super.children,
    this.stepIndex,
    this.divider = true,
    this.dividerSpacingInPixels = 20,
    this.padding = EdgeInsets.zero,
    this.contentPadding = EdgeInsets.zero,
    this.titleStyle,
    super.visibleIf,
    super.enabledIf,
  });

  /// Label shown beside the review content, or above it on compact screens.
  final String title;

  /// Zero-based wizard step opened by the automatic Edit link.
  final int? stepIndex;

  /// Separates review rows; the final row can lead directly into totals.
  final bool divider;

  /// Space between this row and its optional separator.
  final double dividerSpacingInPixels;

  /// Insets around the review content, before its separator.
  final EdgeInsetsGeometry padding;

  /// Insets within the content column, independent of the row heading.
  final EdgeInsetsGeometry contentPadding;

  /// Optional heading typography within a compact review hierarchy.
  final TextStyle? titleStyle;
}

/// Visual treatment of a form card or secondary disclosure.
enum BeakCardPresentation {
  /// Themed card surface with a border and padding.
  surface,

  /// Borderless content; collapsible cards use an inline disclosure header.
  plain,
}

/// A card containing reusable form nodes, with an optional heading.
class BeakCard extends BeakFormLayout {
  /// Groups related inputs in a titled card.
  const BeakCard({
    this.title,
    required super.children,
    this.description,
    this.padding,
    this.headerGapInPixels = 16,
    this.headerSubtitle,
    this.headerTrailing,
    this.collapseLeading = false,
    this.disclosurePadding,
    this.collapsible = false,
    this.initiallyExpanded = true,
    this.presentation = BeakCardPresentation.surface,
    super.spacingInPixels,
    super.visibleIf,
    super.enabledIf,
  });

  /// Heading displayed above this content.
  final String? title;

  /// Optional guidance below the card heading.
  final String? description;

  /// Inner inset of a surface card; omitted values follow the card theme.
  /// Plain sections keep their borderless layout without an additional inset.
  final EdgeInsetsGeometry? padding;

  /// Space after a surface card header; ignored when no header is declared.
  final double headerGapInPixels;

  /// Typed supporting metadata retained below the heading when collapsed.
  final BeakValueBinding<Object>? headerSubtitle;

  /// Typed caption at the trailing edge of the heading.
  final BeakValueBinding<Object>? headerTrailing;

  /// Optional interior header spacing for a plain collapsible card.
  final EdgeInsetsGeometry? disclosurePadding;

  /// Places the disclosure before the heading for compact summary cards.
  final bool collapseLeading;

  /// Allows collapsing the card without removing its fields from the draft.
  final bool collapsible;

  /// Initial expansion state when [collapsible] is enabled.
  final bool initiallyExpanded;

  /// Surface geometry; the same draft owns both presentations.
  final BeakCardPresentation presentation;
}

/// Separate read and edit presentations sharing the same loaded draft.
final class BeakModeLayout extends BeakFormLayout {
  /// Both branches declare their dependencies and remain in the same graph.
  BeakModeLayout({required this.read, required this.edit})
    : super(children: [read, edit]);

  /// Presentation while the parent form is read-only.
  final BeakFormLayout read;

  /// Presentation while the parent form is editable.
  final BeakFormLayout edit;
}

/// Explains an unavailable action without registering a callable command.
final class BeakFormLock extends BeakFormNode {
  /// A disabled control with contextual guidance, for policy-locked actions.
  const BeakFormLock({
    required this.label,
    this.description,
    this.icon,
    super.visibleIf,
  });

  /// The action which cannot currently be performed.
  final String label;

  /// Explains why the action is unavailable.
  final String? description;

  /// Optional lock or other contextual icon.
  final IconData? icon;
}

/// Responsive side-by-side form content.
class BeakColumns extends BeakFormLayout {
  /// Places child sections side by side.
  const BeakColumns({
    required super.children,
    this.columns = 2,
    this.minColumnWidthInPixels = 280,
    this.gapInPixels = 16,
    this.columnWidths = const [],
    this.padding = EdgeInsets.zero,
    super.visibleIf,
    super.enabledIf,
  }) : assert(columns > 0),
       assert(minColumnWidthInPixels > 0);

  /// Number of columns at the active responsive breakpoint.
  final int columns;

  /// Minimum comfortable column width before the layout stacks vertically.
  final double minColumnWidthInPixels;

  /// Gap between columns and stacked children.
  final double gapInPixels;

  /// Optional fixed widths; null cells share the remaining available width.
  final List<double?> columnWidths;

  /// Optional inset around this group without introducing another surface.
  final EdgeInsetsGeometry padding;
}

/// A lightweight form section with a heading and optional explanation.
class BeakSection extends BeakFormLayout {
  /// Groups a related set of inputs without adding another card border.
  const BeakSection({
    required this.title,
    required super.children,
    this.description,
    this.descriptionStyle,
    this.titleStyle,
    this.titleColor,
    this.trailing,
    this.headingGapInPixels = 4,
    this.gapInPixels = 16,
    this.divider = false,
    this.dividerAfterSpacingInPixels = 0,
    super.visibleIf,
    super.enabledIf,
  }) : assert(headingGapInPixels >= 0),
       assert(gapInPixels >= 0);

  /// Section heading.
  final String title;

  /// Optional guidance below the heading.
  final String? description;

  /// Optional typography for section guidance; the theme body is the default.
  final TextStyle? descriptionStyle;

  /// Optional heading typography; unspecified properties inherit the theme.
  final TextStyle? titleStyle;

  /// Optional semantic heading color, resolved from the current theme.
  final BeakColor? titleColor;

  /// Short typed metadata beside the section heading, wrapping when needed.
  final BeakValueBinding<Object>? trailing;

  /// Spacing between the heading and its supporting description.
  final double headingGapInPixels;

  /// Spacing between the heading group and each content node.
  final double gapInPixels;

  /// Additional spacing after a section separator, independent of content gaps.
  final double dividerAfterSpacingInPixels;

  /// Separates this section from a preceding section with the themed divider.
  final bool divider;
}

/// A tab whose inputs belong to the same draft as the other tabs.
class BeakTab extends BeakFormLayout {
  /// Creates a tab with optional visibility and an icon.
  const BeakTab({
    required this.title,
    required super.children,
    super.spacingInPixels,
    this.icon,
    this.badge,
    this.showValidationBadge = true,
    super.visibleIf,
    super.enabledIf,
  });

  /// Text displayed on the tab selector.
  final String title;

  /// Optional icon displayed beside the tab title.
  final IconData? icon;

  /// Optional live count; validation errors take precedence when present.
  final BeakValueBinding<int>? badge;

  /// Whether this tab exposes a validation count beside its title.
  final bool showValidationBadge;
}

/// A tabbed layout; every tab is validated and saved by the enclosing form.
class BeakTabs extends BeakFormLayout {
  /// Creates tabs without introducing extra form controllers or save handlers.
  const BeakTabs({
    required List<BeakTab> tabs,
    this.initialIndex = 0,
    this.acrossRegions = false,
    super.visibleIf,
    super.enabledIf,
  }) : assert(initialIndex >= 0),
       super(children: tabs);

  /// Promotes a sole root tab selector above both content and aside regions.
  final bool acrossRegions;

  /// Initially active tab, clamped when visibility reduces the tab count.
  final int initialIndex;

  /// Declared tabs, in their display order.
  List<BeakTab> get tabs =>
      children.whereType<BeakTab>().toList(growable: false);
}

/// One automatically validated page of a configured wizard.
class BeakWizardStep extends BeakFormLayout {
  /// Creates one page of an automatically validated wizard.
  const BeakWizardStep({
    required this.title,
    required super.children,
    this.description,
    this.heading,
    this.introduction,
    this.introductionBuilder,
    this.continueLabel,
    this.completedDescription,
    this.footerHint,
    this.footerHintBuilder,
    this.dependencies = const [],
    super.spacingInPixels,
    super.visibleIf,
    super.enabledIf,
  });

  /// Short title displayed in step navigation.
  final String title;

  /// Short guidance displayed in step navigation.
  final String? description;

  /// Main step heading, pinned above a rail wizard's scrolling inputs.
  /// Defaults to [title]; ordinary sections remain part of the scrolling body.
  final String? heading;

  /// Main step guidance, independent of the short navigation description.
  /// Defaults to [description].
  final String? introduction;

  /// Live introductory text derived from this wizard's single draft.
  final String Function(BeakFormReader state, BeakFormatPolicy formatting)?
  introductionBuilder;

  /// Related values used by live step metadata, loaded with the form.
  final List<BeakFieldRef<Object>> dependencies;

  /// Optional context-specific forward label, preserving automatic validation.
  final String? continueLabel;

  /// Replaces navigation guidance after this step has been completed.
  /// Reads the shared live draft and panel formatting policy, so returning to
  /// edit updates the summary without creating another owner for its state.
  final String? Function(BeakFormReader state, BeakFormatPolicy formatting)?
  completedDescription;

  /// Supporting text between the back and continue actions in a rail wizard.
  final String? footerHint;

  /// Live footer guidance; ordinary navigation and validation remain automatic.
  final String Function(BeakFormReader state, BeakFormatPolicy formatting)?
  footerHintBuilder;
}

/// Reuses section content across a stacked form, tabbed detail, and wizard.
/// Conditions stay attached to the section when the presentation changes.
final class BeakFormSections {
  /// Creates a reusable presentation from ordinary typed layout nodes.
  const BeakFormSections({required this.sections});

  /// Ordered, titled sections shared by every projection.
  final List<BeakSection> sections;

  /// A stacked form suitable for compact screens and review views.
  BeakFormLayout get form => BeakFormLayout(children: sections);

  /// A tabbed presentation over the same field declarations.
  BeakTabs get tabs => BeakTabs(
    tabs: [
      for (final section in sections)
        BeakTab(
          title: section.title,
          visibleIf: section.visibleIf,
          enabledIf: section.enabledIf,
          children: [
            BeakSection(
              title: section.title,
              description: section.description,
              titleStyle: section.titleStyle,
              titleColor: section.titleColor,
              descriptionStyle: section.descriptionStyle,
              headingGapInPixels: section.headingGapInPixels,
              gapInPixels: section.gapInPixels,
              divider: section.divider,
              children: section.children,
            ),
          ],
        ),
    ],
  );

  /// Wizard steps sharing the same fields, rules, and editability conditions.
  List<BeakWizardStep> get steps => [
    for (final section in sections)
      BeakWizardStep(
        title: section.title,
        description: section.description,
        visibleIf: section.visibleIf,
        enabledIf: section.enabledIf,
        children: section.children,
      ),
  ];
}

/// A typed input placement, including its local presentation and validation.
class BeakInput<T extends Object> extends BeakFormNode {
  /// Places a typed scalar input in a form.
  const BeakInput({
    required this.field,
    this.label,
    this.labelBuilder,
    this.dependencies = const [],
    this.description,
    this.validate = const [],
    this.validators = const [],
    super.enabledIf,
    this.submitWhenHidden = false,
    this.readOnly = false,
    this.derive,
    this.obscureText = false,
    this.currency = false,
    this.minorUnits = false,
    this.currencyScale = 2,
    this.presentation = BeakInputPresentation.automatic,
    this.choices,
    this.choiceMinWidthInPixels,
    this.choiceCardPadding,
    this.groupLabelAsField = false,
    this.allowCustom = false,
    this.maxLines,
    this.placeholder,
    this.showCounter,
    this.controlHeightInPixels,
    this.multilineContentPadding,
    this.controlWidthInPixels,
    this.dateShortcuts,
    this.attributeType,
    this.attributeDefinition,
    this.attributeVersion,
    super.visibleIf,
  }) : assert(currencyScale >= 0 && currencyScale <= 12),
       assert(maxLines == null || maxLines > 0);

  /// Generated typed field bound automatically to this placement.
  final BeakScalarField<T> field;

  /// Optional label overriding the model metadata.
  final String? label;

  /// A contextual label, e.g. a confirmation checkbox naming its recipient.
  final String Function(BeakFormReader state)? labelBuilder;

  /// Fields read by dynamic presentation, eagerly loaded and permission checked.
  final List<BeakFieldRef<Object>> dependencies;

  /// Optional guidance displayed with the input.
  final String? description;

  /// Validates visible placements and nested drafts, awaiting asynchronous rules.
  final List<BeakRule> validate;

  /// Additional asynchronous or synchronous draft-aware validators.
  final List<BeakFieldValidator<T>> validators;

  /// Whether a hidden scalar value is still included in the submitted command.
  final bool submitWhenHidden;

  /// Whether user editing is disabled for this input.
  final bool readOnly;

  /// Whether the text input conceals its characters.
  final bool obscureText;

  /// Whether this placement uses a localized monetary editor and display.
  final bool currency;

  /// Whether a monetary editor stores integer minor units (for example cents).
  final bool minorUnits;

  /// Decimal places in numeric minor-unit storage; independent of display currency.
  final int currencyScale;

  /// Optional control override without changing the model's value type.
  final BeakInputPresentation presentation;

  /// Available values recomputed from the live draft.
  final BeakInputChoices? choices;

  /// Optional minimum radio card width; cards wrap into equal-width columns.
  final double? choiceMinWidthInPixels;

  /// Optional padding for description-bearing choice cards.
  final EdgeInsetsGeometry? choiceCardPadding;

  /// Uses the ordinary input label role for a radio choice group.
  final bool groupLabelAsField;

  /// Whether a tag editor accepts values outside its suggestions.
  final bool allowCustom;

  /// Overrides the visible text editor line count without changing storage.
  final int? maxLines;

  /// Optional text prompt, independent of the accessible label.
  final String? placeholder;

  /// Overrides multiline character counter visibility, retaining model limits.
  final bool? showCounter;

  /// Minimum editor height, excluding its label and supporting text.
  /// The editor grows naturally for larger text or multiline content.
  final double? controlHeightInPixels;

  /// Optional multiline editor padding scoped to this placement.
  final EdgeInsetsGeometry? multilineContentPadding;

  /// Optional width for a bounded quantity control.
  final double? controlWidthInPixels;

  /// Suggested calendar dates; arbitrary calendar dates remain selectable.
  final List<BeakInputOption<BeakDate>> Function(BeakFormReader)? dateShortcuts;

  /// Dynamic interpretation for string-backed configurable attributes.
  final BeakAttributeType Function(BeakFormReader state)? attributeType;

  /// Shared definition supplying attribute labels, options, and validation.
  final BeakAttributeDefinition? Function(BeakFormReader state)?
  attributeDefinition;

  /// Revision stored with the attribute value, when definition changes are tracked.
  final int? Function(BeakFormReader state)? attributeVersion;

  /// Reactive calculation whose tracked field reads automatically update this value.
  final T? Function(BeakFormReader state)? derive;

  /// Validation and server errors indexed by the declared field key.
  Future<List<String>> errors(BeakFormReader state) async {
    final value = state.read(field);
    final raw = state.draft.controller.validationValueOf(field.column);
    final errors = [...const BeakValidation().columnErrors(field.column, raw)];
    for (final rule in validate) {
      if (value == null && rule is! BeakRequired) continue;
      final message = rule.validate(value);
      if (message != null) errors.add(message);
    }
    final definition = attributeDefinition?.call(state);
    if (definition != null) {
      final issue = definition.validate(
        value is String ? value : null,
        version: attributeVersion?.call(state),
      );
      if (issue != null) errors.add(issue);
    }
    final options = choices?.call(state);
    final attribute = attributeType?.call(state);
    if (value != null &&
        attribute == BeakAttributeType.number &&
        (value is! String || num.tryParse(value)?.isFinite != true)) {
      errors.add('Enter a valid number.');
    }
    if (value != null &&
        attribute == BeakAttributeType.boolean &&
        value != 'true' &&
        value != 'false') {
      errors.add('Choose Yes or No.');
    }
    if (options != null &&
        !allowCustom &&
        value != null &&
        (attribute == null || attribute == BeakAttributeType.choice)) {
      final selected = value is List<Object> ? value : [value];
      if (selected.any(
        (item) =>
            !options.any((option) => option.enabled && option.value == item),
      )) {
        errors.add('Choose an available option.');
      }
    }
    for (final validator in validators) {
      final message = await validator(value, state);
      if (message != null) errors.add(message);
    }
    return errors;
  }
}

/// A searchable relationship picker whose query follows draft dependencies.
class BeakRelationInput extends BeakFormNode {
  /// Places an automatically bound relationship lookup.
  const BeakRelationInput({
    required this.field,
    this.label,
    this.description,
    this.descriptionBuilder,
    this.descriptionInline = false,
    this.dependencies = const [],
    this.divider = false,
    this.validate = const [],
    this.options,
    super.enabledIf,
    this.createForm,
    this.exclusive = true,
    this.presentation = BeakRelationPresentation.combobox,
    this.template,
    this.selectionSummary,
    this.searchSources = const [],
    this.createLabel,
    this.createLabelBuilder,
    this.createDescription,
    this.createIcon,
    this.disabledReason,
    this.minCardWidthInPixels = 260,
    this.defaultOption,
    this.defaultOptionMatch,
    this.selectDefaultOption = false,
    this.defaultOptionLabel = 'Default',
    this.compact = false,
    this.cardPadding,
    this.codeField,
    this.normalizeCode,
    this.placeholder,
    super.visibleIf,
  }) : assert(minCardWidthInPixels > 0);

  /// Generated typed field bound automatically to this placement.
  final BeakToOneField field;

  /// Optional label overriding the model metadata.
  final String? label;

  /// Optional guidance displayed with the input.
  final String? description;

  /// Live guidance computed from the owning draft.
  final String? Function(BeakFormReader state)? descriptionBuilder;

  /// A related record from the owning draft identifying its recommended card.
  /// Include this path in [dependencies] to load its identity automatically.
  final BeakToOneField? defaultOption;

  /// Matches a recommended option against the owner draft. Declare every owner
  /// field used here in [dependencies]; only loaded, eligible options qualify.
  final bool Function(BeakRecord option, BeakFormReader state)?
  defaultOptionMatch;

  /// Suggests a matching loaded default when no relationship is selected.
  /// Manual selections remain authoritative until the query invalidates them.
  final bool selectDefaultOption;

  /// Caption shown on the recommended option, independently of selection.
  final String defaultOptionLabel;

  /// Places short guidance beside the heading, wrapping on narrow screens.
  final bool descriptionInline;

  /// Fields read by live labels and guidance, loaded with the form graph.
  final List<BeakFieldRef<Object>> dependencies;

  /// Separates this choice group from preceding form content.
  final bool divider;

  /// Validates visible placements and nested drafts, awaiting asynchronous rules.
  final List<BeakRule> validate;

  /// Declarative lookup query recomputed when its draft dependencies change.
  final BeakOptionQuery Function(BeakFormReader state)? options;

  /// Local dialog layout for creating a related option.
  final BeakFormLayout? createForm;

  /// Whether selection is restricted to existing records.
  final bool exclusive;

  /// Optional label for the inline creation action.
  final String? createLabel;

  /// Live action name, for example creating a profile for the selected customer.
  final String Function(BeakFormReader state)? createLabelBuilder;

  /// Supporting text for the creation row below searchable choices.
  final String? createDescription;

  /// Optional icon for the inline creation action.
  final IconData? createIcon;

  /// Explicit typed search paths, or searchable template fields and relation defaults.
  final List<BeakScalarField<Object>> searchSources;

  /// Selects the visual control; binding and validation remain identical.
  final BeakRelationPresentation presentation;

  /// Typed identity, subtitle, avatar and badge presentation for each option.
  final BeakRecordTemplate? template;

  /// Owner-draft calculation beside an applied exact-code relationship.
  final BeakCalculated? selectionSummary;

  /// Minimum width before relation cards wrap into another row.
  final double minCardWidthInPixels;

  /// Uses compact padding and a trailing selection check for cards.
  final bool compact;

  /// Optional rich choice card inset; null preserves the presentation default.
  final EdgeInsetsGeometry? cardPadding;

  /// Unique string identifier on the target model for [BeakRelationPresentation.code].
  final BeakScalarField<String>? codeField;

  /// Optional canonicalization before an exact code lookup, e.g. uppercase.
  final String Function(String code)? normalizeCode;

  /// Input hint for code entry, without changing the accessible label.
  final String? placeholder;

  /// Optional availability explanation, also enforced during form validation.
  final BeakOptionDisabledReason? disabledReason;
}

/// Visual arrangement of a locally staged relation collection.
enum BeakRelationTablePresentation {
  /// Independently grouped row cards, suited to several inline inputs.
  cards,

  /// Compact separated rows, suited to a shared identity and a few cells.
  rows,
}

/// How additional row inputs are opened without introducing another draft.
enum BeakAdvancedPresentation {
  /// A checkpointed dialog; Cancel restores the row and its descendants.
  dialog,

  /// A disclosure within the row; changes stay in the parent form draft.
  inline,
}

/// Editable related rows. Changes belong to the parent draft until Finish.
class BeakRelationTable extends BeakFormNode {
  /// Configures locally staged relationship rows.
  const BeakRelationTable({
    required this.field,
    required this.children,
    this.label,
    this.showHeading = true,
    this.showAddAction = true,
    this.showColumnHeadings,
    this.rowPadding = const EdgeInsets.symmetric(vertical: 12),
    this.rowMinHeightInPixels = 0,
    this.rowGapInPixels = 16,
    this.reserveActions = false,
    this.minRowWidthInPixels = 560,
    this.identityControlHeightInPixels,
    this.identityControlWidthInPixels = 140,
    this.showRowDividers = true,
    this.identityFlex = 2,
    this.identityChildren = const [],
    this.columnWidths = const [],
    this.columnAlignments = const [],
    this.advancedForm,
    this.advancedContentPadding = const EdgeInsets.all(12),
    this.advancedPresentation = BeakAdvancedPresentation.dialog,
    this.advancedReadVisibleIf,
    this.catalog,
    this.rowTemplate,
    this.presentation = BeakRelationTablePresentation.cards,
    this.readOnly = false,
    this.allowAdding = true,
    this.allowEdit = true,
    this.allowRemove = true,
    this.minRows = 0,
    this.removeBehavior = BeakRemoveBehavior.detach,
    super.enabledIf,
    this.summary,
    this.summaryFormat = BeakValueFormat.text,
    this.summaryLabel,
    super.visibleIf,
  }) : assert(minRows >= 0),
       assert(identityFlex > 0),
       assert(rowMinHeightInPixels >= 0),
       assert(minRowWidthInPixels > 0),
       assert(
         identityControlHeightInPixels == null ||
             identityControlHeightInPixels > 0,
       );

  /// Generated typed field bound automatically to this placement.
  final BeakToManyField field;

  /// Minimum number of nonremoved rows required before the form can save.
  final int minRows;

  /// Ordered child nodes rendered in this layout.
  final List<BeakFormNode> children;

  /// Optional label overriding the model metadata.
  final String? label;

  /// Whether to repeat the collection heading inside the owning section/card.
  final bool showHeading;

  /// Renders the default add control; use BeakRelationAdd to place it elsewhere.
  final bool showAddAction;

  /// Shows compact-row column headings independently of the collection title.
  /// Omitted, follows [showHeading] for existing configurations.
  final bool? showColumnHeadings;

  /// Insets around each row when [presentation] uses compact rows.
  final EdgeInsetsGeometry rowPadding;

  /// Minimum total compact-row height; wrapped content can grow naturally.
  final double rowMinHeightInPixels;

  /// Horizontal space between identity, data columns and row actions.
  final double rowGapInPixels;

  /// Retains the action column in read mode to align read and edit values.
  final bool reserveActions;

  /// Width below which compact row cells stack with their labels.
  /// Fixed cell widths may require stacking sooner to avoid clipping.
  final double minRowWidthInPixels;

  /// Optional input height for controls beside compact identity metadata.
  /// Other inputs retain the surrounding theme's control size.
  final double? identityControlHeightInPixels;

  /// Width of an inline identity control, independent of the whole row.
  final double identityControlWidthInPixels;

  /// Whether compact rows display a subtle separator above each row.
  final bool showRowDividers;

  /// Relative width of the identity beside each scalar cell in desktop rows.
  final int identityFlex;

  /// Compact controls placed beside the identity metadata, for example Size.
  /// These have the same binding, validation and ownership as [children].
  final List<BeakFormNode> identityChildren;

  /// Preferred widths of compact-row cells, in the order of [children].
  /// Null or omitted entries share the remaining width. Narrow rows stack.
  final List<double?> columnWidths;

  /// Optional alignment inside each data column, applied in read and edit mode.
  final List<AlignmentGeometry> columnAlignments;

  /// Additional row inputs displayed using [advancedPresentation].
  final BeakFormLayout? advancedForm;

  /// Insets for an inline advanced form surface; dialogs retain their layout.
  final EdgeInsetsGeometry advancedContentPadding;

  /// Dialog or inline disclosure for [advancedForm]. Both use the same draft.
  final BeakAdvancedPresentation advancedPresentation;

  /// Optional condition for inline advanced details in read-only compact rows,
  /// for example only when a row contains extras or a note. Editing remains
  /// available through the same advanced form.
  final BeakVisibility? advancedReadVisibleIf;

  /// Optional searchable catalog that stages new owned rows automatically.
  final BeakRelationCatalog? catalog;

  /// Optional identity presentation above each row's editable fields.
  final BeakRecordTemplate? rowTemplate;

  /// Row geometry; graph ownership, validation and saving stay identical.
  final BeakRelationTablePresentation presentation;

  /// Displays the existing collection without introducing another edit owner.
  final bool readOnly;

  /// Whether new local rows may be added.
  final bool allowAdding;

  /// Whether existing row inputs may be edited.
  final bool allowEdit;

  /// Whether a row may be removed from this relationship.
  final bool allowRemove;

  /// Whether persisted removals detach membership or delete an owned record.
  final BeakRemoveBehavior removeBehavior;

  /// Reactive summary of the current, nonremoved row drafts.
  final Object? Function(List<BeakFormReader> rows)? summary;

  /// Display formatting applied to the summary result.
  final BeakValueFormat summaryFormat;

  /// Optional heading displayed alongside the formatted summary.
  final String? summaryLabel;

  /// Complete row layout combining inline and advanced inputs.
  BeakFormLayout get rowLayout {
    final nodes = [...identityChildren, ...children, ?advancedForm];
    bool contains(BeakFormNode node, String key) => switch (node) {
      BeakRelationInput(:final field) => field.key == key,
      BeakInput<Object>(:final field) => field.key == key,
      BeakFormLayout(:final children) => children.any(
        (child) => contains(child, key),
      ),
      _ => false,
    };
    if (catalog case final BeakRelationCatalog source) {
      if (!nodes.any((node) => contains(node, source.selection.key))) {
        nodes.add(
          BeakRelationInput(
            field: source.selection,
            template: source.template,
            options: source.options == null
                ? null
                : (state) => source.options!(state.parent ?? state),
            disabledReason: source.disabledReason == null
                ? null
                : (record, state) =>
                      source.disabledReason!(record, state.parent ?? state),
          ),
        );
      }
      if (source.quantity case final BeakScalarField<int> quantity) {
        if (!nodes.any((node) => contains(node, quantity.key))) {
          nodes.add(quantity.input());
        }
      }
    }
    return BeakFormLayout(children: nodes);
  }
}

/// Layout of a catalog sharing the same option query and staged collection.
enum BeakCatalogPresentation {
  /// Compact checkbox choices, each staging or removing one related row.
  checkboxes,

  /// Spacious cards for rich product descriptions.
  cards,

  /// Compact separated rows with inline variant, price and quantity controls.
  rows,
}

/// Describes how catalog records become locally staged collection rows.
///
/// [selection] belongs to the collection's row model. Its target is the catalog
/// model, so choosing an option binds that relationship and lets model defaults
/// and behavior populate quantity, prices and other fields.
final class BeakRelationCatalog {
  /// Creates a declarative catalog without a second form or save handler.
  const BeakRelationCatalog({
    required this.selection,
    required this.template,
    this.options,
    this.disabledReason,
    this.searchLabel = 'Search catalog',
    this.addLabel = 'Add',
    this.groupBy,
    this.variantLabel,
    this.price,
    this.quantity,
    this.searchSources = const [],
    this.tabs = const [],
    this.filters = const [],
    this.maxOptions,
    this.pageSize,
    this.presentation = BeakCatalogPresentation.cards,
    this.compactToolbar = false,
    this.columnLabels,
    this.notice,
    this.footer,
    this.dependencies = const [],
    this.groupOrder,
    this.controlHeightInPixels,
    this.advancedLabel,
  }) : assert(maxOptions == null || maxOptions > 0),
       assert(
         presentation != BeakCatalogPresentation.checkboxes ||
             (groupBy == null && quantity == null && maxOptions != null),
         'Checkbox catalogs require a finite maxOptions and no quantity or grouping.',
       ),
       assert(pageSize == null || pageSize > 0),
       assert(
         pageSize == null || maxOptions != null,
         'Group pagination requires an explicit finite maxOptions.',
       );

  /// Relationship on a new row that receives the selected catalog record.
  final BeakToOneField selection;

  /// Shared typed presentation of each available catalog record.
  final BeakRecordTemplate template;

  /// Catalog layout; narrow rows stack their controls without changing the draft.
  final BeakCatalogPresentation presentation;

  /// Places search beside segmented categories and renders facets as chips.
  /// Narrow containers stack the controls without changing their state.
  final bool compactToolbar;

  /// Optional headings aligned with compact row identity, variant and quantity.
  final ({String item, String variant, String quantity})? columnLabels;

  /// Advisory content between filtering controls and the catalog rows.
  /// It observes the collection owner's draft, not an individual catalog item.
  final BeakFormNotice? notice;

  /// Supporting guidance after the catalog, such as the scope of its first tab.
  final String? footer;

  /// Owner fields used by dynamic facets and group ordering.
  final List<BeakFieldRef<Object>> dependencies;

  /// Preferred group keys in display order; other groups retain query order.
  final List<Object> Function(BeakFormReader state)? groupOrder;

  /// Optional compact input height; touch targets still follow the UI kit.
  final double? controlHeightInPixels;

  /// Optional metadata link for selected options, including a visibility rule.
  /// Its typed dependencies belong to the catalog model and load automatically.
  final BeakValueBinding<String>? advancedLabel;

  /// Catalog query, evaluated against the collection owner's current draft.
  final BeakOptionQuery Function(BeakFormReader state)? options;

  /// Optional availability explanation for a catalog option.
  final BeakOptionDisabledReason? disabledReason;

  /// Optional catalog grouping, for example variants grouped by product ID.
  final BeakScalarField<Object>? groupBy;

  /// Option text in a grouped variant selector.
  final BeakScalarField<String>? variantLabel;

  /// Formatted catalog price displayed beside the selected variant.
  final BeakScalarField<Object>? price;

  /// Quantity field on the staged row, enabling direct increment/decrement.
  final BeakScalarField<int>? quantity;

  /// Typed catalog search paths. Defaults also include searchable template fields.
  final List<BeakScalarField<Object>> searchSources;

  /// Mutually exclusive category filters; the first tab is initially selected.
  final List<BeakCatalogFilter> tabs;

  /// Independently selectable filters combined with the current tab and query.
  final List<BeakCatalogFilter> filters;

  /// Explicit finite option bound for a small catalog. All matching records must
  /// fit inside this bound before groups are rendered, avoiding partial variants.
  final int? maxOptions;

  /// Local group count per page; requires [maxOptions]. Staged rows persist
  /// across pages, search terms and filter changes.
  final int? pageSize;

  /// Search field label.
  final String searchLabel;

  /// Action label for adding one row.
  final String addLabel;
}

/// A named typed catalog query constraint; null represents all options.
final class BeakCatalogFilter {
  /// Defines a category tab or independently toggled catalog facet.
  const BeakCatalogFilter({
    required this.label,
    this.filter,
    this.filterBuilder,
    this.matches,
    this.dependencies = const [],
  });

  /// Visible category or facet name.
  final String label;

  /// Query constraint on the catalog model, including typed related paths.
  final BeakFilter? filter;

  /// Additional scope evaluated from the collection owner's live draft.
  /// Declare related reads in [BeakRelationCatalog.dependencies].
  final BeakFilter? Function(BeakFormReader state)? filterBuilder;

  /// Optional local presentation facet over the fully loaded bounded catalog.
  /// Requires [BeakRelationCatalog.maxOptions]; never replaces server policies.
  final bool Function(BeakRecord record)? matches;

  /// Typed fields read by [matches], including automatically loaded relationships.
  final List<BeakFieldRef<Object>> dependencies;
}

/// A neutral placeholder for content waiting on another form selection.
final class BeakFormPlaceholder extends BeakFormNode {
  /// Uses the UI kit's hatch surface without introducing loading state.
  const BeakFormPlaceholder({
    required this.label,
    this.heightInPixels = 96,
    this.template,
    super.visibleIf,
  });

  /// Explanation of the missing selection or empty section.
  final String label;

  /// Minimum presentation height.
  final double heightInPixels;

  /// Optional live preview of the record that will populate this region.
  final BeakRecordTemplate? template;
}

/// Reuses a record template against the enclosing live draft.
final class BeakFormTemplate extends BeakFormNode {
  /// Creates a reactive display with automatically inferred relation loads.
  const BeakFormTemplate({required this.template, super.visibleIf});

  /// Typed presentation reused across forms, lists and relationship choices.
  final BeakRecordTemplate template;
}

/// Shared workflow toolbar with close and local draft actions.
final class BeakFormHeader extends BeakFormNode {
  /// Declares a fullscreen workflow header without application event handlers.
  const BeakFormHeader({
    required this.title,
    this.description,
    this.showClose = true,
    this.showDraftAction = true,
    this.showDraftSavedAt = true,
    super.visibleIf,
  });

  /// Workflow name.
  final String title;

  /// Optional supporting text beside the title.
  final String? description;

  /// Offers the ordinary guarded return to the resource list.
  final bool showClose;

  /// Offers local draft persistence when the screen configures a draft store.
  final bool showDraftAction;

  /// Shows the last successful local draft write, including automatic saves.
  final bool showDraftSavedAt;
}

/// One formatted line in a live form summary.
final class BeakSummaryLine {
  /// Declares a value computation over the enclosing draft.
  const BeakSummaryLine({
    required this.label,
    required this.value,
    this.format = BeakValueFormat.text,
    this.emphasized = false,
    this.dependencies = const [],
    this.labelBuilder,
    this.subtitle,
    this.visibleIf,
    this.dividerBefore = false,
    this.dividerSpacingInPixels = 0,
    this.valueStyle,
    this.labelStyle,
    this.valueCaption,
    this.valueLabel,
    this.subtitleStyle,
    this.subtitleGapInPixels = 2,
    this.afterSpacingInPixels = 0,
    this.valueAlignment = CrossAxisAlignment.start,
  });

  /// Left-hand label.
  final String label;

  /// Live value; it is never persisted by this presentation.
  final Object? Function(BeakFormReader state) value;

  /// Shared panel formatting policy.
  final BeakValueFormat format;

  /// Highlights a subtotal or other important line.
  final bool emphasized;

  /// Related fields used only by this summary, loaded automatically.
  final List<BeakFieldRef<Object>> dependencies;

  /// Optional reactive label, with [label] as its configuration fallback.
  final String Function(BeakFormReader state, BeakFormatPolicy formatting)?
  labelBuilder;

  /// Secondary explanation below the label, such as an included tax breakdown.
  final String? Function(BeakFormReader state, BeakFormatPolicy formatting)?
  subtitle;

  /// Omits irrelevant lines without changing the form data.
  final BeakVisibility? visibleIf;

  /// Adds a themed separator above an important line, such as the grand total.
  final bool dividerBefore;

  /// Extra vertical space on each side of [dividerBefore], in addition to the
  /// enclosing summary's regular line gap.
  final double dividerSpacingInPixels;

  /// Typography merged with the value's normal or emphasized theme variant.
  final TextStyle? valueStyle;

  /// Typography merged with the label's normal or emphasized theme variant.
  final TextStyle? labelStyle;

  /// Optional formatted value text, for example an amount followed by “left”.
  final String Function(BeakFormReader state, BeakFormatPolicy formatting)?
  valueLabel;

  /// Typography merged with the secondary explanation.
  final TextStyle? subtitleStyle;

  /// Gap between the label and its secondary explanation.
  final double subtitleGapInPixels;

  /// Additional space below this line, before the summary line gap.
  final double afterSpacingInPixels;

  /// Alignment of a horizontal value beside its label and subtitle.
  final CrossAxisAlignment valueAlignment;

  /// Optional short context before the value, such as its previous amount.
  final String? Function(BeakFormReader state, BeakFormatPolicy formatting)?
  valueCaption;
}

/// One value in a joined, responsive metric strip.
final class BeakFormMetric extends BeakSummaryLine {
  /// Uses the same typed form reader and format policy as summary lines.
  const BeakFormMetric({
    required super.label,
    required super.value,
    super.format,
    super.labelBuilder,
    super.dependencies,
    this.description,
    super.subtitle,
    super.valueStyle,
    this.flex = 1,
  }) : assert(flex > 0);

  /// Optional supporting explanation.
  final String? description;

  /// Relative horizontal space within each responsive row.
  final int flex;
}

/// A joined metric strip observed from the existing form draft.
final class BeakFormMetrics extends BeakFormNode {
  /// Creates responsive metric cells without additional requests or state.
  const BeakFormMetrics({
    required this.metrics,
    this.minColumnWidthInPixels = 200,
    this.padding = const EdgeInsets.all(20),
    this.gapInPixels = 6,
    this.inset = false,
    super.visibleIf,
  }) : assert(minColumnWidthInPixels > 0);

  /// Interior spacing shared by all metric cells.
  final EdgeInsetsGeometry padding;

  /// Spacing between label, value, and description.
  final double gapInPixels;

  /// Ordered metric cells.
  final List<BeakFormMetric> metrics;

  /// A subdued inset strip without an outer card border.
  final bool inset;

  /// Minimum cell width before metrics wrap into another row.
  final double minColumnWidthInPixels;

  /// Dependencies loaded and capability-checked automatically.
  List<BeakFieldRef<Object>> get dependencies => [
    for (final metric in metrics) ...metric.dependencies,
  ];
}

/// Compact, reactive label/value rows for summaries and review sections.
final class BeakFormSummary extends BeakFormNode {
  /// Creates summary rows observing the existing form graph.
  const BeakFormSummary({
    required this.lines,
    this.title,
    this.titleStyle,
    this.maxWidthInPixels,
    this.titleColor,
    this.labelColor,
    this.alignment = AlignmentDirectional.centerStart,
    this.gapInPixels = 12,
    this.headingGapInPixels,
    this.source,
    super.visibleIf,
  });

  /// Optional heading.
  final String? title;

  /// Ordered live values.
  final List<BeakSummaryLine> lines;

  /// Optional typography for the summary heading.
  final TextStyle? titleStyle;

  /// Semantic heading color resolved from the current light/dark theme.
  final BeakColor? titleColor;

  /// Semantic color of ordinary labels; emphasized totals retain normal ink.
  final BeakColor? labelColor;

  /// Optional width cap, useful for invoice totals inside a wide section.
  final double? maxWidthInPixels;

  /// Placement of the capped summary within the available width.
  final AlignmentGeometry alignment;

  /// Vertical spacing between individual summary lines.
  final double gapInPixels;

  /// Spacing after the heading; defaults to [gapInPixels].
  final double? headingGapInPixels;

  /// Repeats [lines] for each live child draft, including staged changes.
  /// Line dependencies are relative to the child model and load automatically.
  /// Omit to summarize the enclosing record.
  final BeakToManyField? source;
}

/// A conditional, reactive inline notice in a form or summary.
final class BeakFormNotice extends BeakFormNode {
  /// Creates a persistent informational or validation-related notice.
  const BeakFormNotice({
    required this.message,
    this.title,
    this.titleBuilder,
    this.tone = BeakColor.info,
    this.inline = false,
    this.plain = false,
    this.icon,
    this.caption,
    this.captionIcon,
    this.dependencies = const [],
    super.visibleIf,
  });

  /// Optional semantic icon, including for neutral notices.
  final IconData? icon;

  /// Optional short annotation at the trailing edge of the notice.
  final String? Function(BeakFormReader state)? caption;

  /// Optional decorative icon next to the trailing annotation.
  final IconData? captionIcon;

  /// Places the heading and message on one wrapping line.
  final bool inline;

  /// Optional heading.
  final String? title;

  /// Optional live heading over [dependencies], with [title] as a fallback.
  final String Function(BeakFormReader state)? titleBuilder;

  /// Message evaluated from the same draft as surrounding inputs.
  final String Function(BeakFormReader state) message;

  /// Semantic severity; informational colors use the standard info treatment.
  final BeakColor tone;

  /// Uses a compact icon-and-text line without a banner surface.
  final bool plain;

  /// Related values to load when no editable placement requests them.
  final List<BeakFieldRef<Object>> dependencies;
}

/// Live capacity or budget utilization with consistent formatting and warnings.
final class BeakFormCapacity extends BeakFormNode {
  /// Creates a ratio presentation without introducing stored calculated fields.
  const BeakFormCapacity({
    required this.label,
    required this.value,
    required this.max,
    this.subtitle,
    this.warningText,
    this.warningThreshold = .9,
    this.format = BeakValueFormat.number,
    this.dependencies = const [],
    this.showValue = true,
    this.showLabel = true,
    this.caption,
    this.valueLabel,
    this.heightInPixels = 4,
    this.gapInPixels,
    this.labelStyle,
    this.valueStyle,
    super.visibleIf,
  });

  /// Capacity label.
  final String label;

  /// Optional supporting explanation.
  final String? subtitle;

  /// Track height, independent of text and available width.
  final double heightInPixels;

  /// Optional spacing around the track.
  final double? gapInPixels;

  /// Optional label typography for dense summaries.
  final TextStyle? labelStyle;

  /// Optional ratio typography independent of the capacity label.
  final TextStyle? valueStyle;

  /// Optional localized value text, for example a remaining balance.
  final String Function(BeakFormReader state, BeakFormatPolicy formatting)?
  valueLabel;

  /// Current utilization.
  final num? Function(BeakFormReader state) value;

  /// Total available capacity.
  final num? Function(BeakFormReader state) max;

  /// Optional near-capacity message.
  final String? warningText;

  /// Utilization ratio activating the warning treatment.
  final double warningThreshold;

  /// Number or currency presentation shared with the panel.
  final BeakValueFormat format;

  /// Related fields required by this presentation.
  final List<BeakFieldRef<Object>> dependencies;

  /// Keeps a capacity bar's accessible label while optionally hiding its title.
  final bool showLabel;

  /// Whether the numeric ratio is displayed beside the title.
  final bool showValue;

  /// Reactive supporting explanation below the bar.
  final String? Function(BeakFormReader state, BeakFormatPolicy formatting)?
  caption;
}

/// One persisted workflow milestone with optional typed record details.
final class BeakProgressStep<T extends Enum> {
  /// Omitting [state] declares a milestone preceding the first matching state.
  const BeakProgressStep({
    required this.label,
    this.state,
    this.details,
    this.context,
    this.contextInset = false,
    this.labelBuilder,
    this.dependencies = const [],
  });

  /// Model state represented by this milestone.
  final T? state;

  /// Concise milestone name.
  final String label;

  /// Contextual milestone label using the existing form draft.
  final String Function(BeakFormReader state)? labelBuilder;

  /// Additional fields used by [labelBuilder].
  final List<BeakFieldRef<Object>> dependencies;

  /// Optional time, actor or other record information below the milestone.
  final BeakRecordTemplate? details;

  /// Optional contextual identity beneath the step description.
  final BeakRecordTemplate? context;

  /// Places supplemental identity in a padded neutral surface.
  final bool contextInset;
}

/// Read-only progress through the declared values of a model enum.
final class BeakFormProgress<T extends Enum> extends BeakFormNode {
  /// Uses model enum labels; omitted [states] uses the column's value order.
  const BeakFormProgress({
    required this.field,
    this.states,
    this.steps,
    this.initialState,
    this.planned = false,
    this.labelStyle,
    this.timeline = false,
    this.contextSpacingInPixels = 6,
    super.visibleIf,
  }) : assert(states == null || steps == null);

  /// Current state, updated only by ordinary model behavior or commands.
  final BeakScalarField<T> field;

  /// Presentation fallback used only while the stored state is absent or null.
  /// It does not change the draft or replace unknown/alternate stored states.
  final T? initialState;

  /// Displays a neutral numbered plan without inferring persisted progress.
  final bool planned;

  /// Optional milestone label typography, retaining semantic state indicators.
  final TextStyle? labelStyle;

  /// Uses an intrinsic connected rail for vertical detailed milestones.
  /// Defaults to the existing separated connector layout.
  final bool timeline;

  /// Spacing between milestone details and its contextual record; defaults 6.
  final double contextSpacingInPixels;

  /// Optional normal workflow sequence, excluding alternate terminal states.
  final List<T>? states;

  /// Explicit milestones, including optional preceding events and metadata.
  final List<BeakProgressStep<T>>? steps;

  /// All fields needed by the milestone presentation, loaded with the record.
  List<BeakFieldRef<Object>> get dependencies => [
    field,
    for (final step in steps ?? <BeakProgressStep<T>>[])
      ...?step.details?.fields,
    for (final step in steps ?? <BeakProgressStep<T>>[])
      ...?step.context?.fields,
    for (final step in steps ?? <BeakProgressStep<T>>[]) ...step.dependencies,
  ];
}

/// A collection rendered as a chronological record timeline.
final class BeakFormTimeline extends BeakFormNode {
  /// Reuses typed history fields without a separate query controller.
  const BeakFormTimeline({
    required this.field,
    required this.title,
    required this.time,
    this.description,
    this.compact = false,
    this.messages = false,
    this.emphasizeMentions = false,
    this.inlineTime = false,
    this.actor,
    this.messageIdentity,
    this.columns = 1,
    super.visibleIf,
  });

  /// History relation on the enclosing record.
  final BeakToManyField field;

  /// Primary text on the history row model.
  final BeakScalarField<String> title;

  /// Event time on the history row model.
  final BeakScalarField<DateTime> time;

  /// Optional secondary text on the history row model.
  final BeakScalarField<String>? description;

  /// Renders compact activity rows rather than individual cards.
  final bool compact;

  /// Presents author/time above a neutral message bubble.
  final bool messages;

  /// Highlights conventional @Name mentions inside staff message bubbles.
  final bool emphasizeMentions;

  /// Shows compact time-first connected rows, arranged down each column.
  final bool inlineTime;

  /// Optional actor shown with emphasis before the event title.
  final BeakValueBinding<String>? actor;

  /// Typed identity shown above message bubbles.
  final BeakRecordTemplate? messageIdentity;

  /// Maximum responsive columns used by the compact presentation.
  final int columns;
}

/// Places a collection's managed add action independently of its rows.
/// The collection insertion control's visual presentation.
enum BeakRelationAddPresentation {
  /// A quiet dashed collection action.
  dashed,

  /// An outlined search-shaped action that opens the managed editor.
  search,
}

/// Opens the declared collection editor over the same owner draft.
final class BeakRelationAdd extends BeakFormNode {
  /// Reuses the declared table layout, validation, permission and draft graph.
  const BeakRelationAdd({
    required this.field,
    this.label,
    this.caption,
    this.presentation = BeakRelationAddPresentation.dashed,
    this.placeholder,
    super.visibleIf,
    super.enabledIf,
  });

  /// Collection already declared by a BeakRelationTable in the same form.
  final BeakToManyField field;

  /// Optional action label.
  final String? label;

  /// Optional supporting deadline or hint.
  final String? caption;

  /// Visual treatment, retaining the same managed insertion behavior.
  final BeakRelationAddPresentation presentation;

  /// Search-like hint; the accessible action retains [label].
  final String? placeholder;
}

/// A typed contact or external destination presented beside other form content.
final class BeakFormLink {
  /// The URI is produced from authorized fields; only safe schemes can launch.
  const BeakFormLink({
    required this.label,
    required this.destination,
    this.icon,
  });

  /// Visible and accessible action label.
  final String label;

  /// Safe absolute URI string, for example `mailto:person@example.com`.
  final BeakValueBinding<String> destination;

  /// Optional themed action icon.
  final IconData? icon;
}

/// Compact external actions using the current draft, without persistence logic.
final class BeakFormLinks extends BeakFormNode {
  /// Dependencies load with the containing form and obey field capabilities.
  const BeakFormLinks({required this.links, super.visibleIf, super.enabledIf});

  /// Ordered links; unavailable or unreadable destinations are omitted.
  final List<BeakFormLink> links;
}

/// Positions authoritative model commands within a form's layout or regions.
final class BeakFormActions extends BeakFormNode {
  /// Null [actions] displays all currently available model commands.
  const BeakFormActions({this.actions, super.visibleIf, super.enabledIf});

  /// Explicit commands, in display order.
  final List<BeakModelAction>? actions;
}

/// Places a model command's typed argument form inline in the current screen.
/// Arguments belong to the parent session, including its unsaved-change guard
/// and optional durable drafts. They are never written as record fields.
final class BeakFormActionInput extends BeakFormNode {
  /// [submitWithForm] reuses these arguments for the primary edit command.
  const BeakFormActionInput({
    required this.action,
    this.layout,
    this.submitWithForm,
    this.optionalWithForm = false,
    this.description,
    this.editDescription,
    this.inlineFooter = false,
    this.footerMinHeightInPixels = 0,
    super.visibleIf,
    super.enabledIf,
  });

  /// Authoritative command used by the inline button in read mode.
  final BeakModelAction action;

  /// Argument placements; omitted uses the command's input model conventions.
  final BeakFormLayout? layout;

  /// Primary edit command that accepts the same argument fields.
  final BeakModelAction? submitWithForm;

  /// Allows an entirely empty argument form when submitting with the record.
  /// The primary command's input model must also permit empty arguments.
  final bool optionalWithForm;

  /// Supporting text below the inputs.
  final String? description;

  /// Supporting text while the arguments save with the parent edit.
  final String? editDescription;

  /// Places guidance and a compact primary action on the same footer row.
  final bool inlineFooter;

  /// Optional minimum footer height across read and staged edit modes.
  final double footerMinHeightInPixels;
}

/// Read-only presentation for a calculated value.
enum BeakCalculatedPresentation {
  /// Inline text, optionally prefixed by a label.
  text,

  /// A labelled field with a subdued value surface.
  field,

  /// A locked checkbox showing an automatic rule or requirement.
  checkbox,

  /// A caption, readable value and optional supporting caption, without a box.
  detail,

  /// A labelled, neutral message well for read-only notes or quotations.
  message,
}

/// A reactive display calculation. It is never written as a model field.
class BeakCalculated extends BeakFormNode {
  /// Displays a reactive calculation from the live draft.
  const BeakCalculated({
    required this.value,
    this.label,
    this.labelBuilder,
    this.description,
    this.subtitle,
    this.textAlign = TextAlign.start,
    this.valueStyle,
    this.display,
    this.descriptionTone = BeakColor.muted,
    this.icon,
    this.presentation = BeakCalculatedPresentation.text,
    this.dependencies = const [],
    this.format = BeakValueFormat.text,
    super.visibleIf,
  });

  /// Reactive display calculation; its result is never submitted.
  final Object? Function(BeakFormReader state) value;

  /// Optional label overriding the model metadata.
  final String? label;

  /// Contextual label evaluated from the same draft as [value].
  final String Function(BeakFormReader state)? labelBuilder;

  /// Supporting explanation below a field or locked checkbox.
  final String Function(BeakFormReader state)? description;

  /// Secondary value text using the same global format policy as [value].
  final String? Function(BeakFormReader state, BeakFormatPolicy formatting)?
  subtitle;

  /// Alignment of the formatted value and its subtitle.
  final TextAlign textAlign;

  /// Pure contextual formatting using the panel locale and timezone policy.
  final String Function(Object? value, BeakFormatPolicy formatting)? display;

  /// Optional semantic value typography override.
  final TextStyle? valueStyle;

  /// Tone of the supporting caption in a labelled detail presentation.
  final BeakColor descriptionTone;

  /// Optional leading value icon, for example a locked date or shipping mode.
  final IconData? icon;

  /// Display treatment; calculated values are never editable or submitted.
  final BeakCalculatedPresentation presentation;

  /// Explicit dependencies for automatic relation loading and read access.
  final List<BeakFieldRef<Object>> dependencies;

  /// Shared panel formatting for the calculated result.
  final BeakValueFormat format;
}

/// A custom widget with access to the same tracked form state.
class BeakFormWidget extends BeakFormNode {
  /// Inserts custom content into a configured form.
  const BeakFormWidget({
    required this.builder,
    this.showOnRead = true,
    super.visibleIf,
    super.enabledIf,
  });

  /// Whether this custom content is useful on a record's read surface.
  final bool showOnRead;

  /// Custom content builder with access to the same local draft.
  final Widget Function(BuildContext context, BeakDraftRecord draft) builder;
}

/// Default input shortcut for any generated scalar field.
extension BeakScalarInputs<T extends Object> on BeakScalarField<T> {
  /// Places the model-appropriate input with optional local overrides.
  BeakInput<T> input({
    String? label,
    String? description,
    List<BeakRule> validate = const [],
    List<BeakFieldValidator<T>> validators = const [],
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
    bool readOnly = false,
    bool submitWhenHidden = false,
    T? Function(BeakFormReader)? derive,
  }) => BeakInput<T>(
    field: this,
    currency: switch (this) {
      BeakFormattedField<T>(:final format) =>
        format == BeakValueFormat.currency,
      _ => false,
    },
    currencyScale: switch (this) {
      BeakFormattedField<T>(:final scale) => scale,
      _ => 2,
    },
    minorUnits: switch (this) {
      BeakFormattedField<T>(:final minorUnits) => minorUnits,
      _ => false,
    },
    label: label,
    description: description,
    validate: validate,
    validators: validators,
    visibleIf: visibleIf,
    enabledIf: enabledIf,
    readOnly: readOnly,
    submitWhenHidden: submitWhenHidden,
    derive: derive,
  );
}

/// Text placement helpers for generated string fields.
extension BeakTextInputs on BeakScalarField<String> {
  /// Places a text input with declarative conditions and validation.
  BeakInput<String> inputText({
    String? label,
    String? description,
    int? maxLines,
    String? placeholder,
    bool? showCounter,
    double? controlHeightInPixels,
    EdgeInsetsGeometry? multilineContentPadding,
    List<BeakRule> validate = const [],
    List<BeakFieldValidator<String>> validators = const [],
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
    bool readOnly = false,
    bool obscureText = false,
    bool submitWhenHidden = false,
    String? Function(BeakFormReader)? derive,
  }) => BeakInput(
    field: this,
    label: label,
    description: description,
    maxLines: maxLines,
    placeholder: placeholder,
    showCounter: showCounter,
    controlHeightInPixels: controlHeightInPixels,
    multilineContentPadding: multilineContentPadding,
    validate: validate,
    validators: validators,
    visibleIf: visibleIf,
    enabledIf: enabledIf,
    readOnly: readOnly,
    obscureText: obscureText,
    submitWhenHidden: submitWhenHidden,
    derive: derive,
  );
}

/// Numeric placement helpers for generated number fields.
extension BeakNumericInputs<T extends num> on BeakScalarField<T> {
  /// Places a numeric input using the model precision and limits.
  BeakInput<T> inputNumber({
    String? label,
    String? description,
    List<BeakRule> validate = const [],
    List<BeakFieldValidator<T>> validators = const [],
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
    bool readOnly = false,
    bool submitWhenHidden = false,
    T? Function(BeakFormReader)? derive,
  }) => input(
    label: label,
    description: description,
    validate: validate,
    validators: validators,
    visibleIf: visibleIf,
    enabledIf: enabledIf,
    readOnly: readOnly,
    submitWhenHidden: submitWhenHidden,
    derive: derive,
  );

  /// Places a localized currency editor while keeping the draft value numeric.
  /// Set [minorUnits] for integer cent fields; the editor then scales amounts
  /// using [scale] decimal places, independent of the display currency.
  BeakInput<T> inputCurrency({
    String? label,
    String? description,
    List<BeakRule> validate = const [],
    List<BeakFieldValidator<T>> validators = const [],
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
    bool readOnly = false,
    bool minorUnits = false,
    int scale = 2,
    bool submitWhenHidden = false,
    T? Function(BeakFormReader)? derive,
  }) => BeakInput<T>(
    field: this,
    label: label,
    description: description,
    validate: validate,
    validators: validators,
    visibleIf: visibleIf,
    enabledIf: enabledIf,
    readOnly: readOnly,
    submitWhenHidden: submitWhenHidden,
    derive: derive,
    currency: true,
    minorUnits: minorUnits,
    currencyScale: scale,
  );
}

/// Toggle placement helpers for generated boolean fields.
extension BeakBooleanInputs on BeakScalarField<bool> {
  /// Places a checkbox using the same boolean field and validation as a toggle.
  BeakInput<bool> inputCheckbox({
    String? label,
    String Function(BeakFormReader state)? labelBuilder,
    String? description,
    List<BeakFieldRef<Object>> dependencies = const [],
    List<BeakRule> validate = const [],
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
  }) => BeakInput<bool>(
    field: this,
    label: label,
    description: description,
    validate: validate,
    visibleIf: visibleIf,
    enabledIf: enabledIf,
    presentation: BeakInputPresentation.checkbox,
    labelBuilder: labelBuilder,
    dependencies: dependencies,
  );

  /// Places a boolean switch bound to the draft.
  BeakInput<bool> inputToggle({
    String? label,
    String? description,
    List<BeakRule> validate = const [],
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
  }) => input(
    label: label,
    description: description,
    validate: validate,
    visibleIf: visibleIf,
    enabledIf: enabledIf,
  );
}

/// Date/time placement helpers for generated date fields.
extension BeakDateInputs on BeakScalarField<DateTime> {
  /// Places a date/time input bound to the draft.
  BeakInput<DateTime> inputDateTime({
    String? label,
    String? description,
    List<BeakRule> validate = const [],
    List<BeakFieldValidator<DateTime>> validators = const [],
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
  }) => input(
    label: label,
    description: description,
    validate: validate,
    validators: validators,
    visibleIf: visibleIf,
    enabledIf: enabledIf,
  );
}

/// Relationship lookup helpers for generated to-one fields.
extension BeakToOneInputs on BeakToOneField {
  /// Looks up an exact identifier and stages its relation until the form saves.
  /// The lookup retains model eligibility, dependent filters and permissions.
  BeakRelationInput inputCode({
    required BeakScalarField<String> codeField,
    String Function(String code)? normalizeCode,
    String? label,
    String? description,
    String? Function(BeakFormReader)? descriptionBuilder,
    String? placeholder,
    BeakRecordTemplate? template,
    BeakCalculated? selectionSummary,
    BeakOptionQuery Function(BeakFormReader)? options,
    BeakOptionDisabledReason? disabledReason,
    List<BeakRule> validate = const [],
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
  }) => BeakRelationInput(
    field: this,
    presentation: BeakRelationPresentation.code,
    codeField: codeField,
    selectionSummary: selectionSummary,
    normalizeCode: normalizeCode,
    label: label,
    description: description,
    descriptionBuilder: descriptionBuilder,
    placeholder: placeholder,
    template: template,
    options: options,
    disabledReason: disabledReason,
    validate: validate,
    visibleIf: visibleIf,
    enabledIf: enabledIf,
  );

  /// Places a searchable, dependent relationship selector.
  BeakRelationInput inputCombobox({
    BeakRecordTemplate? template,
    String? label,
    String? description,
    List<BeakScalarField<Object>> searchSources = const [],
    String? createLabel,
    List<BeakRule> validate = const [],
    BeakOptionQuery Function(BeakFormReader)? options,
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
    bool exclusive = true,
    BeakFormLayout? createForm,
  }) => BeakRelationInput(
    field: this,
    template: template,
    label: label,
    description: description,
    searchSources: searchSources,
    createLabel: createLabel,
    validate: validate,
    options: options,
    visibleIf: visibleIf,
    enabledIf: enabledIf,
    exclusive: exclusive,
    createForm: createForm,
  );

  /// Presents automatically filtered options as rich radio cards.
  BeakRelationInput inputCards({
    BeakRecordTemplate? template,
    double minCardWidthInPixels = 260,
    BeakToOneField? defaultOption,
    bool Function(BeakRecord option, BeakFormReader state)? defaultOptionMatch,
    bool selectDefaultOption = false,
    String defaultOptionLabel = 'Default',
    bool compact = false,
    EdgeInsetsGeometry? cardPadding,
    bool exclusive = true,
    BeakFormLayout? createForm,
    String? label,
    String? description,
    String? Function(BeakFormReader)? descriptionBuilder,
    bool descriptionInline = false,
    List<BeakFieldRef<Object>> dependencies = const [],
    bool divider = false,
    List<BeakScalarField<Object>> searchSources = const [],
    String? createLabel,
    String Function(BeakFormReader)? createLabelBuilder,
    List<BeakRule> validate = const [],
    BeakOptionQuery Function(BeakFormReader)? options,
    BeakOptionDisabledReason? disabledReason,
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
  }) => BeakRelationInput(
    field: this,
    template: template,
    minCardWidthInPixels: minCardWidthInPixels,
    defaultOption: defaultOption,
    defaultOptionMatch: defaultOptionMatch,
    selectDefaultOption: selectDefaultOption,
    defaultOptionLabel: defaultOptionLabel,
    compact: compact,
    cardPadding: cardPadding,
    exclusive: exclusive,
    createForm: createForm,
    label: label,
    description: description,
    descriptionBuilder: descriptionBuilder,
    descriptionInline: descriptionInline,
    dependencies: dependencies,
    divider: divider,
    searchSources: searchSources,
    createLabel: createLabel,
    createLabelBuilder: createLabelBuilder,
    validate: validate,
    options: options,
    disabledReason: disabledReason,
    visibleIf: visibleIf,
    enabledIf: enabledIf,
    presentation: BeakRelationPresentation.cards,
  );

  /// Shows a searchable inline list using the same relation eligibility rules.
  BeakRelationInput inputSearch({
    BeakRecordTemplate? template,
    bool exclusive = true,
    BeakFormLayout? createForm,
    String? label,
    String? description,
    String? Function(BeakFormReader)? descriptionBuilder,
    List<BeakFieldRef<Object>> dependencies = const [],
    List<BeakScalarField<Object>> searchSources = const [],
    String? createLabel,
    String? createDescription,
    IconData? createIcon,
    List<BeakRule> validate = const [],
    BeakOptionQuery Function(BeakFormReader)? options,
    BeakOptionDisabledReason? disabledReason,
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
  }) => BeakRelationInput(
    field: this,
    template: template,
    exclusive: exclusive,
    createForm: createForm,
    label: label,
    description: description,
    descriptionBuilder: descriptionBuilder,
    dependencies: dependencies,
    searchSources: searchSources,
    createLabel: createLabel,
    createDescription: createDescription,
    createIcon: createIcon,
    validate: validate,
    options: options,
    disabledReason: disabledReason,
    visibleIf: visibleIf,
    enabledIf: enabledIf,
    presentation: BeakRelationPresentation.search,
  );
}

/// Related collection helpers for generated to-many fields.
extension BeakToManyInputs on BeakToManyField {
  /// Places an editable related collection whose changes save with its owner.
  BeakRelationTable tableForm({
    required List<BeakFormNode> children,
    String? label,
    bool showHeading = true,
    bool showAddAction = true,
    bool? showColumnHeadings,
    EdgeInsetsGeometry rowPadding = const EdgeInsets.symmetric(vertical: 12),
    double rowMinHeightInPixels = 0,
    double rowGapInPixels = 16,
    bool reserveActions = false,
    double minRowWidthInPixels = 560,
    double? identityControlHeightInPixels,
    double identityControlWidthInPixels = 140,
    bool showRowDividers = true,
    int identityFlex = 2,
    List<BeakFormNode> identityChildren = const [],
    List<double?> columnWidths = const [],
    List<AlignmentGeometry> columnAlignments = const [],
    BeakFormLayout? advancedForm,
    EdgeInsetsGeometry advancedContentPadding = const EdgeInsets.all(12),
    BeakAdvancedPresentation advancedPresentation =
        BeakAdvancedPresentation.dialog,
    BeakVisibility? advancedReadVisibleIf,
    BeakRelationCatalog? catalog,
    BeakRecordTemplate? rowTemplate,
    BeakRelationTablePresentation presentation =
        BeakRelationTablePresentation.cards,
    bool readOnly = false,
    bool allowAdding = true,
    bool allowEdit = true,
    bool allowRemove = true,
    int minRows = 0,
    BeakRemoveBehavior removeBehavior = BeakRemoveBehavior.detach,
    Object? Function(List<BeakFormReader>)? summary,
    BeakValueFormat summaryFormat = BeakValueFormat.text,
    String? summaryLabel,
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
  }) => BeakRelationTable(
    field: this,
    children: children,
    label: label,
    showHeading: showHeading,
    showAddAction: showAddAction,
    showColumnHeadings: showColumnHeadings,
    rowPadding: rowPadding,
    rowMinHeightInPixels: rowMinHeightInPixels,
    rowGapInPixels: rowGapInPixels,
    reserveActions: reserveActions,
    minRowWidthInPixels: minRowWidthInPixels,
    identityControlHeightInPixels: identityControlHeightInPixels,
    identityControlWidthInPixels: identityControlWidthInPixels,
    showRowDividers: showRowDividers,
    identityFlex: identityFlex,
    identityChildren: identityChildren,
    columnWidths: columnWidths,
    columnAlignments: columnAlignments,
    advancedForm: advancedForm,
    advancedContentPadding: advancedContentPadding,
    advancedPresentation: advancedPresentation,
    advancedReadVisibleIf: advancedReadVisibleIf,
    catalog: catalog,
    rowTemplate: rowTemplate,
    presentation: presentation,
    readOnly: readOnly,
    allowAdding: allowAdding,
    allowEdit: allowEdit,
    allowRemove: allowRemove,
    minRows: minRows,
    removeBehavior: removeBehavior,
    summary: summary,
    summaryFormat: summaryFormat,
    summaryLabel: summaryLabel,
    visibleIf: visibleIf,
    enabledIf: enabledIf,
  );
}

/// Presentation and editability of custom widgets inside an automatic form.
class BeakDraftScope extends InheritedWidget {
  /// Exposes the existing draft without introducing a second controller.
  const BeakDraftScope({
    required this.draft,
    required this.readOnly,
    required this.enabled,
    required super.child,
    super.key,
  });

  /// Live record shared by surrounding configured inputs.
  final BeakDraftRecord draft;

  /// Whether the enclosing screen displays values rather than editing controls.
  final bool readOnly;

  /// Whether the custom widget may offer editing actions now.
  final bool enabled;

  /// Reads the nearest automatic form presentation.
  static BeakDraftScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<BeakDraftScope>();
    if (scope == null) {
      throw const BeakConfigurationException('No BeakDraftScope is mounted.');
    }
    return scope;
  }

  @override
  bool updateShouldNotify(BeakDraftScope oldWidget) =>
      draft != oldWidget.draft ||
      readOnly != oldWidget.readOnly ||
      enabled != oldWidget.enabled;
}
