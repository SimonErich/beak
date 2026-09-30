import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'app_setting.beak.dart';

/// AppSetting configuration shared by the panel and authoritative API.
@Resource(timestamps: true)
final class AppSetting extends BeakSchema {
  /// Key.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String key;

  /// Value.
  late final String value;

  /// Description.
  @Column(defaultValue: '')
  late final String? description;
}
