import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'email.dart';

part 'mail_label.beak.dart';

/// The mail-labels resource — colored email tags.
@Resource()
final class MailLabel extends BeakSchema {
  /// Label name.
  @Display()
  @Column(searchable: true, rules: [BeakMaxLength(40)])
  late final String name;

  /// Label color.
  late final BeakHexColor? color;

  /// Emails carrying this label, via the `email_mail_label` pivot.
  @BelongsToMany()
  late final List<Email> emails;
}
