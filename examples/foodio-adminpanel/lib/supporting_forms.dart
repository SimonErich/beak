import 'package:beak/panel.dart';

/// One layout is shared by detail, creation and editing for supporting records.
BeakFormScreen supportingForm(List<BeakFormNode> children) => BeakFormScreen(
  roles: const {
    BeakScreenRole.create,
    BeakScreenRole.edit,
    BeakScreenRole.read,
  },
  layout: BeakFormLayout(children: children),
);

/// Labels are separate from stored choice keys throughout supporting forms.
List<BeakInputOption<Object>> choices(Map<String, String> values) => [
  for (final entry in values.entries) BeakInputOption(entry.key, entry.value),
];
