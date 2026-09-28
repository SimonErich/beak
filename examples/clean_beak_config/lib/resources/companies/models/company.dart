import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'company.beak.dart';

/// Company schema; all metadata and typed helpers are generated.
@Resource()
final class Company extends BeakSchema {
  /// Company name used in pickers.
  @Display()
  @Column(searchable: true, rules: [BeakMaxLength(120)])
  late final String name;
}
