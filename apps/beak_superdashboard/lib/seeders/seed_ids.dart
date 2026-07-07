/// Fixed primary keys for the seed's cross-domain anchors — UUID-shaped but
/// stable, so one hero user threads through orders, invoices, transactions,
/// chats, cards, and activity, and tests can reference records by name.
abstract final class SeedIds {
  /// Aisha — admin, top spender.
  static const userAisha = '00000000-0000-4000-8000-000000000301';

  /// Marcus — editor.
  static const userMarcus = '00000000-0000-4000-8000-000000000302';

  /// Priya — author, designer.
  static const userPriya = '00000000-0000-4000-8000-000000000303';

  /// Diego — maintainer.
  static const userDiego = '00000000-0000-4000-8000-000000000304';

  /// Hannah — editor.
  static const userHannah = '00000000-0000-4000-8000-000000000305';

  /// Ken — author.
  static const userKen = '00000000-0000-4000-8000-000000000306';

  /// Lena — subscriber.
  static const userLena = '00000000-0000-4000-8000-000000000307';

  /// Omar — subscriber.
  static const userOmar = '00000000-0000-4000-8000-000000000308';

  /// Every hero user id, in display order.
  static const List<String> heroUsers = [
    userAisha,
    userMarcus,
    userPriya,
    userDiego,
    userHannah,
    userKen,
    userLena,
    userOmar,
  ];

  /// The single project board.
  static const board = '00000000-0000-4000-8000-0000000000b1';

  /// The featured pricing plan.
  static const featuredPlan = '00000000-0000-4000-8000-0000000000f2';
}
