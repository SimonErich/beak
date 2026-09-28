import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/panel_fixtures.dart';

const _pictures = BeakToManyField(
  model: _Catalog(),
  relation: _Catalog.pictures,
  target: _Picture(),
);
const _image = BeakScalarField<String>(
  model: _Picture(),
  column: _Picture.image,
);
const _caption = BeakScalarField<String>(
  model: _Picture(),
  column: _Picture.caption,
);
const _position = BeakScalarField<int>(
  model: _Picture(),
  column: _Picture.position,
);

void main() {
  test(
    'gallery orders locally and saves order, captions and owned removals with parent',
    () async {
      final source = FakeDataSource(models: const [_Catalog(), _Picture()]);
      final gallery = _pictures.galleryForm(
        image: _image,
        caption: _caption,
        position: _position,
      );
      final session = BeakFormSession(
        model: const _Catalog(),
        dataSource: source,
        layout: BeakFormLayout(children: [gallery]),
      );
      addTearDown(session.dispose);
      final first = gallery.add(session.root)
        ..set(_image, 'existing/a.png')
        ..set(_caption, 'Front');
      final second = gallery.add(session.root)
        ..set(_image, 'existing/b.png')
        ..set(_caption, 'Back');
      gallery.move(session.root, second, -1);
      expect(gallery.orderedRows(session.root), [second, first]);
      expect(source.store.rowsOf('pictures'), isEmpty);
      expect((await session.save())?.complete, isTrue);
      final persisted = source.store.rowsOf('pictures').toList();
      expect(
        persisted
            .where((r) => r['caption']?.raw == 'Back')
            .single['position']
            ?.raw,
        0,
      );
      session.root.removeRow(first);
      expect(source.store.rowsOf('pictures'), hasLength(2));
      expect((await session.save())?.complete, isTrue);
      expect(source.store.rowsOf('pictures'), hasLength(1));
    },
  );

  test('rejects shared collections and mismatched fields', () {
    const shared = BeakToManyField(
      model: _Catalog(),
      target: _Picture(),
      relation: BeakHasMany(
        key: 'pictures',
        label: 'Pictures',
        relatedTable: 'pictures',
        displayColumnKey: 'caption',
        foreignKey: 'catalog_id',
      ),
    );
    expect(
      () => shared.galleryForm(
        image: _image,
        caption: _caption,
        position: _position,
      ),
      throwsA(isA<BeakConfigurationException>()),
    );
    expect(
      () => _pictures.galleryForm(
        image: _caption,
        caption: _caption,
        position: _position,
      ),
      throwsA(isA<BeakConfigurationException>()),
    );
  });
}

final class _Catalog extends BeakModel {
  const _Catalog();
  static const pictures = BeakHasMany(
    key: 'pictures',
    label: 'Pictures',
    relatedTable: 'pictures',
    displayColumnKey: 'caption',
    foreignKey: 'catalog_id',
    owned: true,
  );
  @override
  String get table => 'catalogs';
  @override
  String get displayColumnKey => 'id';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
  ];
  @override
  List<BeakRelationship> get relationships => const [pictures];
  @override
  List<BeakModel> get relatedModels => const [_Picture()];
}

final class _Picture extends BeakModel {
  const _Picture();
  static const image = BeakImageColumn(
    key: 'image',
    label: 'Image',
    storagePath: 'pictures',
  );
  static const caption = BeakStringColumn(
    key: 'caption',
    label: 'Caption',
    rules: [BeakRequired()],
  );
  static const position = BeakIntColumn(
    key: 'position',
    label: 'Position',
    min: 0,
  );
  @override
  String get table => 'pictures';
  @override
  String get displayColumnKey => 'caption';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    image,
    caption,
    position,
    BeakStringColumn(key: 'catalog_id', label: 'Catalog'),
  ];
}
