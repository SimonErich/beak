part of '../beak_block_host.dart';

/// Fetches a [BeakVideoBlock]'s first row and plays it on `OiVideoPlayer`.
class _BeakVideoBlockView extends HookWidget {
  const _BeakVideoBlockView({required this.block});

  final BeakVideoBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakLocator<BeakDataSource>();
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

    final BeakRecord? first = records.value.isEmpty
        ? null
        : records.value.first;
    if (first == null) {
      return const SizedBox(height: 220);
    }
    final String src = first[block.urlField.key]?.raw?.toString() ?? '';
    final String? poster = block.posterField == null
        ? null
        : first[block.posterField!.key]?.raw?.toString();
    return OiVideoPlayer(
      src: src,
      label: block.title ?? 'Video',
      posterUrl: poster,
      autoPlay: block.autoPlay,
      loop: block.loop,
      aspectRatio: 16 / 9,
    );
  }
}
