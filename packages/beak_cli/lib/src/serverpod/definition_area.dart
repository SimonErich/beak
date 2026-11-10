import 'definition_model.dart';
import 'generate_issue.dart';
import 'generate_settings.dart';

/// Reports an unknown area, a write without roles and a closed model
/// without a reason.
void checkDefinitionArea(
  DefinitionClass definition,
  BeakGenerateSettings settings,
  BeakIssueSink issues,
) {
  final area = definition.area;
  if (area != null && !settings.areas.containsKey(area)) {
    issues.add(
      definition.path,
      '${definition.name}: the area "$area" is not declared in '
      'generate.areas (${settings.areas.keys.join(', ')}).',
    );
  }
  if (definition.writes &&
      area == null &&
      !definition.access.containsKey('write') &&
      !definition.hasPermissions) {
    issues.add(
      definition.path,
      '${definition.name} opens writes but names no area, no '
      "access: {'write': [...]} and no static permissions.",
    );
  }
  if (!definition.writes && (definition.reason?.trim().isEmpty ?? true)) {
    issues.add(
      definition.path,
      '${definition.name} opens no writes, so @ServerpodModel(reason:) says '
      'why.',
    );
  }
}
