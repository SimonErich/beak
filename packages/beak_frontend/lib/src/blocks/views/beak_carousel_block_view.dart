part of '../beak_block_host.dart';

/// Runs a [BeakCarouselBlock]'s query and turns each row into an image slide
/// inside an `OiCarousel`.
class _BeakCarouselBlockView extends HookWidget {
  const _BeakCarouselBlockView({required this.block});

  final BeakCarouselBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakDependencies(context)<BeakDataSource>();
    final revision = useBeakDataRevision(dataSource, table: block.query.table);
    final slides = useState(const <_Slide>[]);

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
          slides.value = [
            for (final record in value.items)
              if (record[block.imageUrlField.key]?.raw?.toString()
                  case final String url when url.isNotEmpty)
                _Slide(
                  url: url,
                  caption: block.captionField == null
                      ? null
                      : record[block.captionField!.key]?.raw?.toString(),
                ),
          ];
        }
      }

      load();
      return () => cancelled = true;
    }, [dataSource, block, revision]);

    if (slides.value.isEmpty) {
      return SizedBox(height: block.heightInPixels);
    }
    return OiCarousel(
      label: 'Carousel',
      height: block.heightInPixels,
      autoplay: block.autoplay,
      items: [
        for (final slide in slides.value)
          OiImage(
            src: slide.url,
            alt: slide.caption ?? 'Slide',
            fit: BoxFit.cover,
          ),
      ],
    );
  }
}

/// One resolved carousel slide.
final class _Slide {
  const _Slide({required this.url, this.caption});

  final String url;
  final String? caption;
}
