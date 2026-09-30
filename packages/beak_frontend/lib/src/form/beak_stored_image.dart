import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';

import '../di/beak_locator.dart';
import 'beak_resolved_image.dart';

/// Displays an image URL or resolves a persisted key through its upload driver.
/// Resolution and loading state are local to the nearest panel, including when
/// several independently configured panels are mounted together.
class BeakStoredImage extends HookWidget {
  /// Displays [storageKey] with accessible [alt] text and optional explicit scope.
  const BeakStoredImage({
    required this.column,
    required this.storageKey,
    required this.alt,
    this.table,
    this.client,
    this.sizeInPixels = 160,
    super.key,
  });

  /// Image column whose upload endpoint owns the key.
  final BeakColumn column;

  /// Storage key or already resolved HTTP/data URL.
  final String storageKey;

  /// Accessible description.
  final String alt;

  /// Model table; inferred from the scoped registry when omitted.
  final String? table;

  /// Overrides the scoped source, for example to preview an unsaved draft.
  final BeakUploadUrlClient? client;

  /// Square image extent in logical pixels.
  final double sizeInPixels;

  @override
  Widget build(BuildContext context) {
    final dependencies = beakDependencies(context);
    final source = dependencies.isRegistered<BeakDataSource>()
        ? dependencies<BeakDataSource>()
        : null;
    final resolver =
        client ??
        switch (source) {
          final BeakUploadUrlClient value => value,
          _ => null,
        };
    final registry = dependencies.isRegistered<BeakModelRegistry>()
        ? dependencies<BeakModelRegistry>()
        : null;
    final owner =
        table ??
        registry?.all
            .where(
              (model) => model.columns.any((value) => identical(value, column)),
            )
            .firstOrNull
            ?.table;
    final uri = Uri.tryParse(storageKey);
    final direct =
        storageKey.startsWith('assets/') ||
        (uri != null && const ['https', 'http', 'data'].contains(uri.scheme));
    final request = useMemoized(
      () => !direct && resolver != null && owner != null
          ? resolver.uploadUrl(owner, column.key, storageKey)
          : null,
      [storageKey, resolver, owner, column.key],
    );
    final result = useFuture(request);
    final url = direct ? uri : result.data;
    return SizedBox(
      width: sizeInPixels,
      height: sizeInPixels,
      child: url != null
          ? BeakResolvedImage(
              src: url.toString(),
              alt: alt,
              widthInPixels: sizeInPixels,
              heightInPixels: sizeInPixels,
              fit: BoxFit.cover,
              errorWidget: const OiIcon.decorative(icon: OiIcons.image),
            )
          : Center(
              child: result.connectionState == ConnectionState.waiting
                  ? const OiLabel.caption('Loading image…')
                  : const OiIcon.decorative(icon: OiIcons.image),
            ),
    );
  }
}
