part of '../beak_block_host.dart';

/// Fetches a [BeakGalleryBlock]'s rows and renders each as a thumbnail on
/// `OiGallery`.
class _BeakGalleryBlockView extends HookWidget {
  const _BeakGalleryBlockView({required this.block});

  final BeakGalleryBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakDependencies(context)<BeakDataSource>();
    final records = _useBlockRead(
      dataSource,
      block.query,
      initial: const <BeakRecord>[],
      map: (page) => page.items,
    );

    return _withReadFailure(
      context,
      records,
      OiGallery(
        label: BeakLocalizations.of(context).gallery,
        columns: block.columns,
        items: [
          for (final (index, record) in records.data.indexed)
            OiGalleryItem(
              key: index,
              src: _readString(record, block.imageUrlField) ?? '',
              alt: _readString(record, block.captionField) ?? '',
            ),
        ],
      ),
    );
  }
}
