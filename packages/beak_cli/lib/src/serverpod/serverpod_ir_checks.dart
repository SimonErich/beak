part of 'serverpod_ir.dart';

void _checkRelationKinds(
  _Draft draft,
  DefinitionResource resource,
  BeakIssueSink issues,
) {
  for (final MapEntry(key: name, value: field) in resource.fields.entries) {
    final kind = field.relation;
    if (kind == null) continue;
    final built = draft.schema.relations
        .where((relation) => relation.fieldName == name)
        .firstOrNull;
    if (built == null) {
      issues.add(
        resource.path,
        '${resource.name}.$name: Serverpod declares no relation Beak can '
        'resolve here.',
      );
    } else if (built.kind.name != kind) {
      issues.add(
        resource.path,
        '${resource.name}.$name is a ${built.kind.name} relation in '
        'Serverpod; annotate it @${_upperFirst(built.kind.name)}().',
      );
    }
  }
}

void _validateRoleNames(
  SpyProject project,
  BeakGenerateSettings settings,
  BeakIssueSink issues,
) {
  final roles = settings.roles;
  if (roles == null || settings.areas.isEmpty) return;
  final roleEnum = project.enums[roles];
  if (roleEnum == null) {
    issues.add(
      'beak.yaml',
      'generate.roles names "$roles", which is not an enum of the server.',
    );
    return;
  }
  final names = {for (final value in roleEnum.values) value.name};
  for (final area in settings.areas.entries) {
    for (final role in [...area.value.read, ...area.value.write]) {
      if (!names.contains(role)) {
        issues.add(
          'beak.yaml',
          'generate.areas.${area.key} names "$role", which $roles does not '
              'declare.',
        );
      }
    }
  }
}
