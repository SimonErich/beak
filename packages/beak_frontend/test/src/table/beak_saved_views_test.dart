import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/panel_fixtures.dart';

void main() {
  test(
    'shared views store complete query choices through ordinary graph forms',
    () async {
      final source = FakeDataSource(models: const [_View()]);
      final controller = BeakQueryController(
        model: const NoteModel(),
        initial: BeakQueryState(search: 'weekly', page: 2, perPage: 50),
      );
      final session = BeakFormSession(
        model: const _View(),
        dataSource: source,
        layout: _store.form(controller),
      );
      addTearDown(controller.dispose);
      addTearDown(session.dispose);
      session.root.set(_name, 'Weekly orders');
      expect((await session.save())?.complete, isTrue);
      final views = await _store.list(source, 'notes');
      expect(views, hasLength(1));
      expect(views.single.name, 'Weekly orders');
      expect(views.single.state.toJson(), controller.state.value.toJson());
      expect(await _store.list(source, 'another-resource'), isEmpty);
      expect(
        () => _store.decode('{'),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => _store.decode(jsonEncode({'version': 2})),
        throwsA(isA<BeakConfigurationException>()),
      );
    },
  );

  test(
    'unsafe return URLs and malformed list bookmarks remain local failures',
    () {
      expect(
        BeakBackButton.destination(
          Uri.parse('/notes/a?returnTo=https%3A%2F%2Fevil.example'),
          '/notes',
        ),
        '/notes',
      );
      expect(
        BeakBackButton.destination(
          Uri.parse('/notes/a?returnTo=%2Fnotes%3Flist%3Dabc'),
          '/notes',
        ),
        '/notes?list=abc',
      );
      expect(
        () =>
            BeakQueryController.readUri(Uri.parse('/notes?list=not%20base64!')),
        throwsA(isA<BeakConfigurationException>()),
      );
    },
  );
}

const _name = BeakScalarField<String>(
  model: _View(),
  column: BeakStringColumn(key: 'name', label: 'Name'),
);
const _resource = BeakScalarField<String>(
  model: _View(),
  column: BeakStringColumn(key: 'resource', label: 'Resource'),
);
const _state = BeakScalarField<String>(
  model: _View(),
  column: BeakStringColumn(key: 'state', label: 'State'),
);
const _store = BeakSavedViewStore.model(
  model: _View(),
  name: _name,
  resource: _resource,
  state: _state,
);

final class _View extends BeakModel {
  const _View();
  @override
  String get table => 'views';
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => [
    const BeakStringColumn(key: 'id', label: 'Id'),
    _name.column,
    _resource.column,
    _state.column,
  ];
}
