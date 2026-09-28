import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'note.beak.dart';

/// A note.
///
/// Declared once. `beak prepare` generates the typed columns, the model, the
/// relationships (both sides), and a typed record view into `note.beak.dart`,
/// so there is no registry to edit.
@Resource(timestamps: true)
final class Note extends BeakSchema {
  /// What the note is called.
  ///
  /// Non-nullable, so it is required: the form validator, the API and the
  /// schema all derive that from the type rather than restating it.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(255)])
  late final String title;

  /// The note itself.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? body;

  /// Whether the note is pinned to the top of the list.
  @Column(filterable: true)
  late final bool pinned;
}
