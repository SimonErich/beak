import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late FakeDataSource dataSource;
  late TableViewModel viewModel;

  setUp(() {
    dataSource = FakeDataSource(
      records: {
        'notes': {
          'n1': BeakRecord.fromRow(const {'id': 'n1', 'title': 'One'}),
        },
      },
    );
    viewModel = TableViewModel(const NoteModel(), dataSource);
  });

  tearDown(() => viewModel.dispose());

  test('refresh loads the page and clears errors', () async {
    await viewModel.refresh();
    expect(viewModel.page.value?.total, 1);
    expect(viewModel.loading.value, isFalse);
    expect(viewModel.error.value, isNull);
  });

  test('sortBy replaces the ordering and resets to the first page', () async {
    viewModel.goToPage(3);
    viewModel.sortBy(const NoteModel().columns[1], descending: true);
    await pumpEventQueue();

    final spec = dataSource.queryCalls.last;
    expect(spec.sorts, [const BeakSort('title', descending: true)]);
    expect(spec.pagination.page, 1, reason: 'sorting restarts pagination');

    viewModel.sortBy(const NoteModel().columns.first);
    await pumpEventQueue();
    expect(dataSource.queryCalls.last.sorts, [
      const BeakSort('id'),
    ], reason: 'sorts replace, never stack');
  });

  test('setSearch searches the searchable columns only', () async {
    viewModel.setSearch('laser');
    await pumpEventQueue();

    final spec = dataSource.queryCalls.last;
    expect(spec.search, const BeakSearch('laser', ['title']));

    viewModel.setSearch('   ');
    await pumpEventQueue();
    expect(dataSource.queryCalls.last.search, isNull);
  });

  test('setFilter replaces and clears the filter tree', () async {
    const filter = BeakFieldFilter.forKey(
      'title',
      BeakOperator.eq,
      BeakStringValue('One'),
    );
    viewModel.setFilter(filter);
    await pumpEventQueue();
    expect(dataSource.queryCalls.last.filter, filter);

    viewModel.setFilter(null);
    await pumpEventQueue();
    expect(dataSource.queryCalls.last.filter, isNull);
  });

  test('goToPage and setPageSize drive pagination', () async {
    viewModel.goToPage(4);
    await pumpEventQueue();
    expect(dataSource.queryCalls.last.pagination.page, 4);

    viewModel.setPageSize(50);
    await pumpEventQueue();
    expect(
      dataSource.queryCalls.last.pagination,
      const BeakPagination(perPage: 50),
    );
  });

  test('failures surface as typed error state', () async {
    final failingViewModel = TableViewModel(
      const NoteModel(),
      _FailingSource(),
    );
    addTearDown(failingViewModel.dispose);

    await failingViewModel.refresh();

    expect(failingViewModel.error.value, isA<BeakStorageException>());
    expect(failingViewModel.loading.value, isFalse);
    expect(failingViewModel.page.value, isNull);
  });
}

/// A data source whose queries always fail.
final class _FailingSource extends FakeDataSource {
  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async {
    throw const BeakStorageException('backend unreachable');
  }
}
