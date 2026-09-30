part of '../beak_block_host.dart';

/// Fetches a [BeakVideoBlock]'s first row and plays it on `OiVideoPlayer`.
class _BeakVideoBlockView extends HookWidget {
  const _BeakVideoBlockView({required this.block});

  final BeakVideoBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakDependencies(context)<BeakDataSource>();
    final records = _useBlockRead(
      dataSource,
      block.query,
      initial: const <BeakRecord>[],
      map: (page) => page.items,
    );

    final BeakRecord? first = records.data.isEmpty ? null : records.data.first;
    if (first == null) {
      return _withReadFailure(context, records, const SizedBox(height: 220));
    }
    final String src = first[block.urlField.key]?.raw?.toString() ?? '';
    final String? poster = block.posterField == null
        ? null
        : first[block.posterField!.key]?.raw?.toString();
    return _withReadFailure(
      context,
      records,
      OiVideoPlayer(
        src: src,
        label: block.title ?? 'Video',
        posterUrl: poster,
        autoPlay: block.autoPlay,
        loop: block.loop,
        aspectRatio: 16 / 9,
      ),
    );
  }
}
