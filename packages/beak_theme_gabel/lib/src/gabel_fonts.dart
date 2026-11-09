/// The prefix Flutter gives every font a package declares in its pubspec.
///
/// An app that depends on `beak_theme_gabel` gets the fonts under this name
/// without declaring them, so every family below carries it.
const _package = 'packages/beak_theme_gabel';

/// Mona Sans, the interface typeface. A variable font with `wght` and `wdth`
/// axes.
const gabelSansFamily = '$_package/Mona Sans';

/// Mona Sans Extended, tried for glyphs [gabelSansFamily] lacks.
const gabelSansFallbackFamilies = ['$_package/Mona Sans Extended'];

/// JetBrains Mono, the code typeface.
const gabelMonoFamily = '$_package/JetBrains Mono';

/// JetBrains Mono Extended, tried for glyphs [gabelMonoFamily] lacks.
const gabelMonoFallbackFamilies = ['$_package/JetBrains Mono Extended'];
