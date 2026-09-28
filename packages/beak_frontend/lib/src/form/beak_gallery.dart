import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

import 'beak_form_layout.dart';
import 'beak_form_session.dart';

/// A media collection using the ordinary owned-relationship save lifecycle.
/// Image, caption and persisted position are typed fields of the child model.
class BeakGallery extends BeakRelationTable {
  /// Configures an ordered gallery without a separate upload or state controller.
  BeakGallery({
    required super.field,
    required this.image,
    required this.caption,
    required this.position,
    super.label,
    super.minRows,
    super.visibleIf,
    super.enabledIf,
    super.allowAdding,
    super.allowEdit,
    super.allowRemove,
    List<BeakFormNode> metadata = const [],
  }) : super(
         removeBehavior: BeakRemoveBehavior.deleteOwned,
         children: [
           image.input(),
           caption.inputText(),
           ...metadata,
           position.input(
             readOnly: true,
             visibleIf: _hidePosition,
             submitWhenHidden: true,
           ),
         ],
       ) {
    if (field.relation case BeakHasMany(owned: true)) {
      for (final child in [image, caption, position]) {
        if (child.model.table != field.target.table || child.path.isNotEmpty) {
          throw const BeakConfigurationException(
            'Gallery fields must belong to its child model.',
          );
        }
      }
    } else {
      throw const BeakConfigurationException(
        'A gallery needs an owned has-many relationship.',
      );
    }
    if (image.column is! BeakImageColumn) {
      throw const BeakConfigurationException(
        'The gallery image must be an image column.',
      );
    }
  }

  /// Child field containing the storage key.
  final BeakScalarField<String> image;

  /// Accessible image description edited alongside the picture.
  final BeakScalarField<String> caption;

  /// Persisted zero-based ordering, updated automatically by move controls.
  final BeakScalarField<int> position;

  static bool _hidePosition(BeakFormReader _) => false;

  /// Current nonremoved rows in their saved presentation order.
  List<BeakDraftRecord> orderedRows(BeakDraftRecord parent) {
    final rows = parent.rows(field).toList();
    final original = {for (var i = 0; i < rows.length; i++) rows[i]: i};
    rows.sort((a, b) {
      final compared = (a.read(position) ?? 0).compareTo(b.read(position) ?? 0);
      return compared == 0 ? original[a]!.compareTo(original[b]!) : compared;
    });
    return rows;
  }

  /// Moves a picture locally; only the eventual graph save persists ordering.
  void move(BeakDraftRecord parent, BeakDraftRecord row, int offset) {
    if (parent.session.submitting.value ||
        parent.session.hasUnknown ||
        !allowEdit ||
        !parent.enabled(this)) {
      return;
    }
    final rows = orderedRows(parent);
    final index = rows.indexOf(row);
    final target = index + offset;
    if (index < 0 || target < 0 || target >= rows.length) return;
    rows.removeAt(index);
    rows.insert(target, row);
    for (var i = 0; i < rows.length; i++) {
      rows[i].set(position, i);
    }
  }

  /// Adds an empty local picture slot after the last current picture.
  BeakDraftRecord add(BeakDraftRecord parent) {
    final rows = orderedRows(parent);
    final next = rows.isEmpty
        ? 0
        : (rows.last.read(position) ?? rows.length - 1) + 1;
    return parent.addRow(
      field,
      values: BeakRecord(values: {position.key: BeakIntValue(next)}),
    );
  }
}

/// Declarative gallery shortcut on a generated relationship field.
extension BeakGalleryField on BeakToManyField {
  /// Displays owned image records as ordered cards with editable metadata.
  BeakGallery galleryForm({
    required BeakScalarField<String> image,
    required BeakScalarField<String> caption,
    required BeakScalarField<int> position,
    String? label,
    int minRows = 0,
    List<BeakFormNode> metadata = const [],
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
  }) => BeakGallery(
    field: this,
    image: image,
    caption: caption,
    position: position,
    label: label,
    minRows: minRows,
    metadata: metadata,
    visibleIf: visibleIf,
    enabledIf: enabledIf,
  );
}

/// Gallery presentation used by the configured form renderer.
class BeakGalleryView extends StatelessWidget {
  /// Renders gallery cards using the form's shared field renderer.
  const BeakGalleryView({
    required this.gallery,
    required this.draft,
    required this.readOnly,
    required this.fieldBuilder,
    super.key,
  });

  /// Typed gallery configuration.
  final BeakGallery gallery;

  /// Parent draft owning the collection.
  final BeakDraftRecord draft;

  /// Whether the screen currently displays saved values only.
  final bool readOnly;

  /// Reuses ordinary inputs and formatting for every gallery field.
  final Widget Function(BeakFormNode, BeakDraftRecord, bool) fieldBuilder;

  @override
  Widget build(BuildContext context) {
    final rows = gallery.orderedRows(draft);
    final locked =
        readOnly ||
        draft.session.submitting.value ||
        draft.session.hasUnknown ||
        !draft.enabled(gallery);
    final label = gallery.label ?? gallery.field.label;
    return OiCard(
      title: OiLabel.h4(label),
      child: OiColumn(
        breakpoint: context.breakpoint,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        gap: const OiResponsive<double>(12),
        children: [
          const OiLabel.body(
            'The first image is the cover. Images and ordering are saved with the record.',
          ),
          if (rows.isEmpty) const OiLabel.body('No images yet.'),
          OiGrid(
            breakpoint: context.breakpoint,
            minColumnWidth: const OiResponsive<double>(260),
            gap: const OiResponsive<double>(16),
            children: [
              for (var i = 0; i < rows.length; i++)
                OiCard(
                  key: ValueKey(rows[i].localId),
                  title: OiLabel.smallStrong(
                    i == 0 ? 'Cover image' : 'Image ${i + 1}',
                  ),
                  child: OiColumn(
                    breakpoint: context.breakpoint,
                    gap: const OiResponsive<double>(12),
                    children: [
                      for (final node in gallery.children)
                        fieldBuilder(
                          node,
                          rows[i],
                          locked || !gallery.allowEdit,
                        ),
                      if (!locked)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (gallery.allowEdit) ...[
                              OiButton.ghost(
                                label: 'Move earlier',
                                enabled: i > 0,
                                onTap: i == 0
                                    ? null
                                    : () => gallery.move(draft, rows[i], -1),
                              ),
                              OiButton.ghost(
                                label: 'Move later',
                                enabled: i < rows.length - 1,
                                onTap: i == rows.length - 1
                                    ? null
                                    : () => gallery.move(draft, rows[i], 1),
                              ),
                            ],
                            if (gallery.allowRemove)
                              OiButton.ghost(
                                label: 'Remove image',
                                onTap: () => draft.removeRow(rows[i]),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          ),
          if (draft.errors[gallery.field.key] case final List<String> errors)
            OiLabel.body(errors.join(' ')),
          if (!locked && gallery.allowAdding)
            OiButton.secondary(
              label: 'Add image',
              onTap: () => gallery.add(draft),
            ),
        ],
      ),
    );
  }
}
