import 'package:beak_superdashboard/models/models.dart';

import 'seed_context.dart';
import 'seed_ids.dart';

/// One fixed hero user — real, recognizable people the whole demo revolves
/// around (they own orders, invoices, chats, cards, and activity).
typedef _Hero = ({
  String id,
  String name,
  String email,
  UserRole role,
  OnlineStatus online,
  String country,
  String code,
  String city,
  String company,
  double balance,
});

/// Seeds the People domain: hero users + faker customers, their skills,
/// the team, and a threaded activity feed.
final class PeopleSeeder {
  /// Creates the seeder.
  const PeopleSeeder();

  static const List<_Hero> _heroes = [
    (
      id: SeedIds.userAisha,
      name: 'Aisha Rahman',
      email: 'aisha.rahman@beak.dev',
      role: UserRole.admin,
      online: OnlineStatus.online,
      country: 'United States',
      code: 'US',
      city: 'New York',
      company: 'Beak Labs',
      balance: 5971.67,
    ),
    (
      id: SeedIds.userMarcus,
      name: 'Marcus Vogel',
      email: 'marcus.vogel@beak.dev',
      role: UserRole.editor,
      online: OnlineStatus.busy,
      country: 'Germany',
      code: 'DE',
      city: 'Berlin',
      company: 'Nordwind Studio',
      balance: 4210.40,
    ),
    (
      id: SeedIds.userPriya,
      name: 'Priya Nair',
      email: 'priya.nair@beak.dev',
      role: UserRole.author,
      online: OnlineStatus.online,
      country: 'United Kingdom',
      code: 'GB',
      city: 'London',
      company: 'Craftly',
      balance: 3890.15,
    ),
    (
      id: SeedIds.userDiego,
      name: 'Diego Santos',
      email: 'diego.santos@beak.dev',
      role: UserRole.maintainer,
      online: OnlineStatus.away,
      country: 'Brazil',
      code: 'BR',
      city: 'São Paulo',
      company: 'Verdeon',
      balance: 2760.00,
    ),
    (
      id: SeedIds.userHannah,
      name: 'Hannah Berg',
      email: 'hannah.berg@beak.dev',
      role: UserRole.editor,
      online: OnlineStatus.online,
      country: 'Sweden',
      code: 'SE',
      city: 'Stockholm',
      company: 'Fjord & Co',
      balance: 3120.90,
    ),
    (
      id: SeedIds.userKen,
      name: 'Ken Watanabe',
      email: 'ken.watanabe@beak.dev',
      role: UserRole.author,
      online: OnlineStatus.offline,
      country: 'Japan',
      code: 'JP',
      city: 'Tokyo',
      company: 'Sakura Systems',
      balance: 4520.25,
    ),
    (
      id: SeedIds.userLena,
      name: 'Lena Fischer',
      email: 'lena.fischer@beak.dev',
      role: UserRole.subscriber,
      online: OnlineStatus.away,
      country: 'Austria',
      code: 'AT',
      city: 'Vienna',
      company: 'Alpenhaus',
      balance: 1980.50,
    ),
    (
      id: SeedIds.userOmar,
      name: 'Omar Haddad',
      email: 'omar.haddad@beak.dev',
      role: UserRole.subscriber,
      online: OnlineStatus.online,
      country: 'France',
      code: 'FR',
      city: 'Paris',
      company: 'Lumière',
      balance: 2340.75,
    ),
  ];

  static const List<String> _skillNames = [
    'Photoshop',
    'Illustrator',
    'HTML',
    'CSS',
    'JavaScript',
    'Dart',
    'Flutter',
    'Python',
    'SQL',
    'Figma',
    'Copywriting',
    'SEO',
  ];

  static const List<String> _countries = [
    'United States',
    'Germany',
    'United Kingdom',
    'France',
    'Spain',
    'Italy',
    'Brazil',
    'Japan',
    'Australia',
    'Canada',
    'Sweden',
    'Netherlands',
  ];

  static const Map<String, String> _codeByCountry = {
    'United States': 'US',
    'Germany': 'DE',
    'United Kingdom': 'GB',
    'France': 'FR',
    'Spain': 'ES',
    'Italy': 'IT',
    'Brazil': 'BR',
    'Japan': 'JP',
    'Australia': 'AU',
    'Canada': 'CA',
    'Sweden': 'SE',
    'Netherlands': 'NL',
  };

  /// Seeds all People-domain rows through [ctx].
  Future<void> seed(SeedContext ctx) async {
    final userRows = <Map<String, Object?>>[];
    final userIds = <String>[];

    for (final hero in _heroes) {
      userIds.add(hero.id);
      userRows.add({
        'id': hero.id,
        'name': hero.name,
        'email': hero.email,
        'phone': ctx.faker.phoneNumber(),
        'role': hero.role.name,
        'status': AccountStatus.active.name,
        'online': hero.online.name,
        'bio': ctx.faker.paragraph(sentenceCount: 3),
        'avatar': ctx.faker.avatarUrl(),
        'cover': ctx.faker.imageUrl(width: 960, height: 320),
        'country': hero.country,
        'country_code': hero.code,
        'city': hero.city,
        'company': hero.company,
        'balance': hero.balance,
        'tasks_done': ctx.between(40, 220),
        'projects_done': ctx.between(4, 28),
        'created_at': ctx.daysAgo(700),
        'updated_at': ctx.daysAgo(20),
      });
    }

    for (var index = 0; index < 32; index++) {
      final id = ctx.uuid();
      userIds.add(id);
      final country = ctx.pick(_countries);
      userRows.add({
        'id': id,
        'name': ctx.faker.name(),
        'email': ctx.faker.email(),
        'phone': ctx.faker.phoneNumber(),
        'role': UserRole.subscriber.name,
        'status': ctx.weighted({
          AccountStatus.active.name: 8,
          AccountStatus.pending.name: 2,
          AccountStatus.inactive.name: 1,
        }),
        'online': ctx.pick(OnlineStatus.values).name,
        'bio': ctx.faker.paragraph(sentenceCount: 2),
        'avatar': ctx.faker.avatarUrl(),
        'cover': ctx.faker.imageUrl(width: 960, height: 320),
        'country': country,
        'country_code': _codeByCountry[country],
        'city': ctx.faker.city(),
        'company': ctx.faker.company(),
        'balance': ctx.money(0, 5200),
        'tasks_done': ctx.between(0, 180),
        'projects_done': ctx.between(0, 20),
        'created_at': ctx.daysAgo(680),
        'updated_at': ctx.daysAgo(40),
      });
    }
    await ctx.insertMany('users', userRows);

    final skillIds = <String>[];
    final skillRows = <Map<String, Object?>>[];
    for (final name in _skillNames) {
      final id = ctx.uuid();
      skillIds.add(id);
      skillRows.add({'id': id, 'name': name});
    }
    await ctx.insertMany('skills', skillRows);

    final userSkillRows = <Map<String, Object?>>[];
    for (final userId in userIds) {
      final chosen = <String>{};
      final count = ctx.between(2, 5);
      while (chosen.length < count) {
        chosen.add(ctx.pick(skillIds));
      }
      for (final skillId in chosen) {
        userSkillRows.add({'user_id': userId, 'skill_id': skillId});
      }
    }
    await ctx.insertMany('user_skill', userSkillRows);

    const teamRoles = [
      'Frontend Dev',
      'UI/UX Designer',
      'Backend Dev',
      'DevOps',
      'Product Lead',
      'QA Engineer',
    ];
    final teamRows = <Map<String, Object?>>[
      for (var index = 0; index < teamRoles.length; index++)
        {
          'id': ctx.uuid(),
          'user_id': SeedIds.heroUsers[index],
          'role': teamRoles[index],
          'status': MembershipStatus.active.name,
          'joined_at': ctx.daysAgo(500),
        },
    ];
    await ctx.insertMany('team_members', teamRows);

    await _seedActivity(ctx);
    await _seedAttachments(ctx);
  }

  Future<void> _seedActivity(SeedContext ctx) async {
    final rows = <Map<String, Object?>>[];
    for (var index = 0; index < 14; index++) {
      final parentId = ctx.uuid();
      rows.add({
        'id': parentId,
        'user_id': ctx.pick(SeedIds.heroUsers),
        'type': ctx.pick([
          ActivityType.comment,
          ActivityType.upload,
          ActivityType.statusChange,
        ]).name,
        'body': ctx.faker.sentence(wordCount: ctx.between(6, 14)),
        'target': ctx.faker.company(),
        'parent_id': null,
        'created_at': ctx.daysAgo(30),
      });
      if (ctx.chance(0.5)) {
        rows.add({
          'id': ctx.uuid(),
          'user_id': ctx.pick(SeedIds.heroUsers),
          'type': ActivityType.reaction.name,
          'body': ctx.faker.sentence(wordCount: ctx.between(4, 9)),
          'target': null,
          'parent_id': parentId,
          'created_at': ctx.daysAgo(28),
        });
      }
    }
    await ctx.insertMany('activities', rows);
  }

  Future<void> _seedAttachments(SeedContext ctx) async {
    const files = [
      ('project-brief.pdf', AttachmentKind.pdf, 2_240_000),
      ('mockups.zip', AttachmentKind.archive, 1_180_000),
      ('spec-sheet.xlsx', AttachmentKind.spreadsheet, 320_000),
      ('demo-clip.mp4', AttachmentKind.video, 8_640_000),
    ];
    final rows = <Map<String, Object?>>[];
    for (final userId in SeedIds.heroUsers) {
      for (final file in files) {
        if (!ctx.chance(0.6)) {
          continue;
        }
        rows.add({
          'id': ctx.uuid(),
          'user_id': userId,
          'name': file.$1,
          'kind': file.$2.name,
          'size': file.$3,
          'file': 'users/files/${file.$1}',
          'created_at': ctx.daysAgo(90),
        });
      }
    }
    await ctx.insertMany('user_attachments', rows);
  }
}
