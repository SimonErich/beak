part of '../beak_block_host.dart';

/// Fetches a [BeakGalleryBlock]'s rows and renders each as a thumbnail on
/// `OiGallery`.
class _BeakGalleryBlockView extends HookWidget {
  const _BeakGalleryBlockView({required this.block});

  final BeakGalleryBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakDependencies(context)<BeakDataSource>();
    final records = useState(const <BeakRecord>[]);

    useEffect(() {
      var cancelled = false;
      Future<void> load() async {
        final result = await BeakResourceRepository(
          dataSource,
        ).query(block.query);
        if (cancelled) {
          return;
        }
        if (result case BeakOk(:final value)) {
          records.value = value.items;
        }
      }

      load();
      return () => cancelled = true;
    }, [dataSource, block]);

    return OiGallery(
      label: 'Gallery',
      columns: block.columns,
      items: [
        for (final (index, record) in records.value.indexed)
          OiGalleryItem(
            key: index,
            src: _readString(record, block.imageUrlField) ?? '',
            alt: _readString(record, block.captionField) ?? '',
          ),
      ],
    );
  }
}
