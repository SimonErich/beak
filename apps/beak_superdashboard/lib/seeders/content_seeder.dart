import 'package:beak_superdashboard/models/models.dart';

import 'seed_context.dart';
import 'seed_ids.dart';

/// One pricing plan definition, with its feature bullets.
typedef _Plan = ({
  String id,
  String name,
  String tagline,
  double monthly,
  double yearly,
  bool featured,
  String? badge,
  List<String> features,
});

/// Seeds the Pricing, FAQ, and showcase-content domains — curated, not
/// faker-generated, because the copy is on screen.
final class ContentSeeder {
  /// Creates the seeder.
  const ContentSeeder();

  static const List<String> _sharedFeatures = [
    '2 Websites',
    '30 GB Storage',
    'Unmetered Bandwidth',
    'Email (1 year trial)',
    'Free domain (annual plan)',
    'Priority support',
  ];

  static final List<_Plan> _plans = [
    (
      id: '00000000-0000-4000-8000-0000000000f1',
      name: 'Starter',
      tagline: 'For individuals getting started',
      monthly: 239,
      yearly: 2390,
      featured: false,
      badge: null,
      features: _sharedFeatures.sublist(0, 3),
    ),
    (
      id: '00000000-0000-4000-8000-0000000000f3',
      name: 'Professional',
      tagline: 'For growing teams',
      monthly: 349,
      yearly: 3490,
      featured: false,
      badge: null,
      features: _sharedFeatures.sublist(0, 4),
    ),
    (
      id: SeedIds.featuredPlan,
      name: 'Enterprise',
      tagline: 'For scaling organizations',
      monthly: 489,
      yearly: 4890,
      featured: true,
      badge: 'Popular',
      features: _sharedFeatures,
    ),
    (
      id: '00000000-0000-4000-8000-0000000000f4',
      name: 'Unlimited',
      tagline: 'For everything you can imagine',
      monthly: 555,
      yearly: 5550,
      featured: false,
      badge: null,
      features: _sharedFeatures,
    ),
  ];

  static const List<({String category, String question, String answer})> _faqs =
      [
        (
          category: 'General',
          question: 'What is Beak Superdashboard?',
          answer:
              'A demo admin panel built entirely from Beak configuration and '
              'seeded data — no hand-written screens.',
        ),
        (
          category: 'General',
          question: 'Can I customize the dashboard?',
          answer:
              'Yes. Every widget is a declarative block you can rearrange, '
              'add to, or bind to a different query.',
        ),
        (
          category: 'Billing',
          question: 'How does billing work?',
          answer:
              'Plans are billed monthly or annually. Annual plans include a '
              'free domain and a discounted rate.',
        ),
        (
          category: 'Billing',
          question: 'Can I change my plan later?',
          answer:
              'You can upgrade or downgrade at any time; changes are '
              'prorated to your next invoice.',
        ),
        (
          category: 'Account',
          question: 'How do I reset my password?',
          answer:
              'Use the "Recover password" link on the sign-in screen and '
              'follow the emailed instructions.',
        ),
        (
          category: 'Account',
          question: 'How do I invite teammates?',
          answer:
              'Open the Users section and add a team member; they receive an '
              'invitation to join your workspace.',
        ),
        (
          category: 'Technical',
          question: 'Which browsers are supported?',
          answer:
              'All modern evergreen browsers, plus desktop and mobile '
              'builds via Flutter.',
        ),
        (
          category: 'Technical',
          question: 'Where is my data stored?',
          answer:
              'In a Postgres database, with file uploads on S3-compatible '
              'storage. Everything here comes from the seeders.',
        ),
      ];

  /// Seeds all content-domain rows through [ctx].
  Future<void> seed(SeedContext ctx) async {
    await _seedPricing(ctx);
    await _seedFaqs(ctx);
    await _seedMedia(ctx);
    await _seedNotifications(ctx);
  }

  Future<void> _seedPricing(SeedContext ctx) async {
    final planRows = <Map<String, Object?>>[];
    final featureRows = <Map<String, Object?>>[];
    for (var index = 0; index < _plans.length; index++) {
      final plan = _plans[index];
      planRows.add({
        'id': plan.id,
        'name': plan.name,
        'tagline': plan.tagline,
        'monthly_price': plan.monthly,
        'yearly_price': plan.yearly,
        'currency': 'USD',
        'featured': plan.featured,
        'badge': plan.badge,
        'sort_index': index,
      });
      for (
        var featureIndex = 0;
        featureIndex < _sharedFeatures.length;
        featureIndex++
      ) {
        featureRows.add({
          'id': ctx.uuid(),
          'plan_id': plan.id,
          'label': _sharedFeatures[featureIndex],
          'included': plan.features.contains(_sharedFeatures[featureIndex]),
          'sort_index': featureIndex,
        });
      }
    }
    await ctx.insertMany('pricing_plans', planRows);
    await ctx.insertMany('plan_features', featureRows);
  }

  Future<void> _seedFaqs(SeedContext ctx) async {
    const categoryNames = ['General', 'Billing', 'Account', 'Technical'];
    final categoryIds = <String, String>{};
    final categoryRows = <Map<String, Object?>>[];
    for (var index = 0; index < categoryNames.length; index++) {
      final id = ctx.uuid();
      categoryIds[categoryNames[index]] = id;
      categoryRows.add({
        'id': id,
        'name': categoryNames[index],
        'icon': 'help-circle',
        'description': 'Answers about ${categoryNames[index].toLowerCase()}.',
        'sort_index': index,
      });
    }
    await ctx.insertMany('faq_categories', categoryRows);

    final faqRows = <Map<String, Object?>>[
      for (var index = 0; index < _faqs.length; index++)
        {
          'id': ctx.uuid(),
          'category_id': categoryIds[_faqs[index].category],
          'question': _faqs[index].question,
          'answer': _faqs[index].answer,
          'featured': index < 3,
          'sort_index': index,
        },
    ];
    await ctx.insertMany('faqs', faqRows);
  }

  Future<void> _seedMedia(SeedContext ctx) async {
    final rows = <Map<String, Object?>>[];
    void add(MediaCollection collection, int count, int width, int height) {
      for (var index = 0; index < count; index++) {
        rows.add({
          'id': ctx.uuid(),
          'collection': collection.name,
          'title': '${collection.name} ${index + 1}',
          'caption': ctx.faker.sentence(wordCount: 6),
          'url': ctx.faker.imageUrl(width: width, height: height),
          'sort_index': index,
        });
      }
    }

    add(MediaCollection.gallery, 8, 600, 400);
    add(MediaCollection.carousel, 4, 1200, 480);
    add(MediaCollection.video, 3, 640, 360);
    await ctx.insertMany('media_assets', rows);
  }

  Future<void> _seedNotifications(SeedContext ctx) async {
    const items = [
      ('New order received', NotificationLevel.success, 'shopping-cart'),
      ('Payment failed', NotificationLevel.error, 'credit-card'),
      ('Storage almost full', NotificationLevel.warning, 'hard-drive'),
      ('New comment on your card', NotificationLevel.info, 'message-circle'),
      ('Weekly report is ready', NotificationLevel.info, 'file-text'),
      ('Subscription renewed', NotificationLevel.success, 'refresh-cw'),
      ('Login from a new device', NotificationLevel.warning, 'shield'),
      ('Team member joined', NotificationLevel.info, 'user-plus'),
    ];
    final rows = <Map<String, Object?>>[
      for (var index = 0; index < items.length; index++)
        {
          'id': ctx.uuid(),
          'title': items[index].$1,
          'body': ctx.faker.sentence(wordCount: 9),
          'level': items[index].$2.name,
          'icon': items[index].$3,
          'is_read': ctx.chance(0.4),
          'created_at': ctx.daysAgo(14),
        },
    ];
    await ctx.insertMany('notifications', rows);
  }
}
