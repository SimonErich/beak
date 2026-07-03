import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late FakeDataSource dataSource;

  setUp(() {
    dataSource = FakeDataSource(
      records: {
        'notes': {
          'n1': BeakRecord.fromRow(const {'id': 'n1', 'title': 'One'}),
        },
      },
    );
  });

  test('create mode skips loading and submits through create', () async {
    final viewModel = FormViewModel(const NoteModel(), dataSource);
    addTearDown(viewModel.dispose);

    expect(viewModel.isEdit, isFalse);
    await viewModel.load();
    expect(viewModel.initial.value, isNull);

    final saved = await viewModel.submit(
      BeakRecord.fromRow(const {'id': 'n2', 'title': 'Two'}),
    );
    expect(saved?['id'], const BeakStringValue('n2'));
    expect(viewModel.saved.value, isNotNull);
  });

  test('edit mode loads the record and submits through update', () async {
    final viewModel = FormViewModel(
      const NoteModel(),
      dataSource,
      recordId: 'n1',
    );
    addTearDown(viewModel.dispose);

    await viewModel.load();
    expect(viewModel.initial.value?['title'], const BeakStringValue('One'));
    expect(viewModel.loading.value, isFalse);

    await viewModel.submit(BeakRecord.fromRow(const {'title': 'One!'}));
    expect(viewModel.saved.value?['title'], const BeakStringValue('One!'));
  });

  test('a 422 lands in fieldErrors, not error', () async {
    final viewModel = FormViewModel(const NoteModel(), _RejectingSource());
    addTearDown(viewModel.dispose);

    final saved = await viewModel.submit(BeakRecord.fromRow(const {}));
    expect(saved, isNull);
    expect(viewModel.fieldErrors.value, {
      'title': ['This field is required.'],
    });
    expect(viewModel.error.value, isNull);
  });

  test('other failures land in error and a resubmit clears them', () async {
    final viewModel = FormViewModel(const NoteModel(), _BrokenSource());
    addTearDown(viewModel.dispose);

    await viewModel.submit(BeakRecord.fromRow(const {'title': 'x'}));
    expect(viewModel.error.value, isA<BeakStorageException>());

    final missingLoad = FormViewModel(
      const NoteModel(),
      dataSource,
      recordId: 'ghost',
    );
    addTearDown(missingLoad.dispose);
    await missingLoad.load();
    expect(missingLoad.error.value, isA<BeakNotFoundException>());
  });
}

/// A source rejecting every write with a validation failure.
final class _RejectingSource extends FakeDataSource {
  @override
  Future<BeakRecord> create(String table, BeakRecord data) async {
    throw const BeakValidationException(
      'Validation failed.',
      fieldErrors: {
        'title': ['This field is required.'],
      },
    );
  }
}

/// A source failing every write with a storage failure.
final class _BrokenSource extends FakeDataSource {
  @override
  Future<BeakRecord> create(String table, BeakRecord data) async {
    throw const BeakStorageException('disk on fire');
  }
}
