part of '../beak_block_host.dart';

/// Owns the local value of a [BeakRadialSliderBlock] and renders an
/// `OiRadialSlider`.
class _BeakRadialSliderBlockView extends HookWidget {
  const _BeakRadialSliderBlockView({required this.block});

  final BeakRadialSliderBlock block;

  @override
  Widget build(BuildContext context) {
    final value = useState(block.initialValue);
    return OiRadialSlider(
      value: value.value,
      min: block.min,
      max: block.max,
      size: block.sizeInPixels,
      label: block.label,
      onChanged: (next) => value.value = next,
    );
  }
}
