part of '../beak_block_host.dart';

/// Fetches a [BeakProfileBlock]'s record and renders its identity on
/// `OiProfilePage`.
class _BeakProfileBlockView extends HookWidget {
  const _BeakProfileBlockView({required this.block});

  final BeakProfileBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakLocator<BeakDataSource>();
    final record = useState<BeakRecord?>(null);

    useEffect(() {
      var cancelled = false;
      Future<void> load() async {
        final result = await BeakResourceRepository(
          dataSource,
        ).getOne(block.model.table, block.recordId);
        if (cancelled) {
          return;
        }
        if (result case BeakOk(:final value)) {
          record.value = value;
        }
      }

      load();
      return () => cancelled = true;
    }, [dataSource, block]);

    final BeakRecord? profile = record.value;
    if (profile == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: OiLabel.body('Loading…'),
      );
    }

    return OiProfilePage(
      label: block.label,
      profile: OiProfileData(
        name: _readString(profile, block.nameField) ?? '',
        email: _readString(profile, block.emailField) ?? '',
        avatarUrl: _readString(profile, block.avatarField),
        role: _readString(profile, block.roleField),
        bio: _readString(profile, block.bioField),
      ),
      // Persist identity-field edits back onto the bound columns; fields
      // without a bound column (e.g. phone) report failure rather than
      // pretending to save.
      onFieldSave: (field, value) async {
        final BeakColumn? column = switch (field) {
          'name' => block.nameField,
          'email' => block.emailField,
          'bio' => block.bioField,
          _ => null,
        };
        if (column == null) {
          return false;
        }
        final result = await BeakResourceRepository(dataSource).update(
          block.model.table,
          block.recordId,
          BeakRecord(values: {column.key: BeakStringValue(value)}),
        );
        if (result case BeakOk(:final value)) {
          record.value = value;
          return true;
        }
        return false;
      },
    );
  }
}
