import 'package:beak/panel.dart';
import 'package:superdashboard/models/models.dart';

/// The skill show page: a headline card naming the competency, above a card
/// listing every user who holds this skill.
const BeakBlock skillDetail = BeakColumnBlock(
  gapInPixels: 20,
  children: [
    BeakCardBlock(title: 'Skill', child: BeakFieldBlock(SkillColumns.name)),
    BeakCardBlock(
      title: 'Users',
      child: BeakRelationBlock(SkillRelations.users),
    ),
  ],
);
