part of '../beak_block_host.dart';

/// Runs a [BeakCarouselBlock]'s query and turns each row into an image slide
/// inside an `OiCarousel`.
class _BeakCarouselBlockView extends HookWidget {
  const _BeakCarouselBlockView({required this.block});

  final BeakCarouselBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakDependencies(context)<BeakDataSource>();
    final slides = _useBlockRead(
      dataSource,
      block.query,
      initial: const <_Slide>[],
      map: (page) => [
        for (final record in page.items)
          if (record[block.imageUrlField.key]?.raw?.toString()
              case final String url when url.isNotEmpty)
            _Slide(
              url: url,
              caption: block.captionField == null
                  ? null
                  : record[block.captionField!.key]?.raw?.toString(),
            ),
      ],
    );

    final Widget view = slides.data.isEmpty
        ? SizedBox(height: block.heightInPixels)
        : OiCarousel(
            label: BeakLocalizations.of(context).carousel,
            height: block.heightInPixels,
            autoplay: block.autoplay,
            items: [
              for (final slide in slides.data)
                OiImage(
                  src: slide.url,
                  alt: slide.caption ?? 'Slide',
                  fit: BoxFit.cover,
                ),
            ],
          );
    return _withReadFailure(context, slides, view);
  }
}

/// One resolved carousel slide.
final class _Slide {
  const _Slide({required this.url, this.caption});

  final String url;
  final String? caption;
}
