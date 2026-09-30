"""Extract supplied design tokens and fonts without executing the prototype.

Run with fonttools[brotli] available. The HTML remains the design source of truth.
Self-contained reference snapshots are written to .artifacts/reference for QA.
Scripts are removed; fonts and other assets are embedded without network access.
"""
from pathlib import Path
import base64
import gzip
import io
import json
import math
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'design/food-ordering-shop.html'

def script(html, kind):
    return json.loads(re.search(r'<script type="__bundler/' + kind + r'">(.*?)</script>', html, re.S).group(1))

def decode(value):
    data = base64.b64decode(value['data'])
    return gzip.decompress(data) if value.get('compressed') else data

def static_template(reference):
    """Restore the bundler's native tags and declared initial conditions."""
    reference = re.sub(r'(<\/?)(?:sc-raw-)([a-z][a-z0-9-]*)(?=[\s>])',
                       r'\1\2', reference)
    condition = re.compile(
        r'<sc-if\b([^>]*)>((?:(?!<\/?sc-if\b).)*?)</sc-if>', re.S)
    def resolve(match):
        value = re.search(r'hint-placeholder-val="\{\{(true|false)\}\}"',
                          match[1])
        if value is None:
            raise ValueError('Reference condition needs a declared initial value')
        return match[2] if value[1] == 'true' else ''
    while '<sc-if' in reference:
        reference, count = condition.subn(resolve, reference)
        if not count:
            raise ValueError('Unbalanced reference conditions')
    return reference.replace('{{theme}}', 'light').replace('{{inverseTheme}}', 'dark')

manifest = script(SOURCE.read_text(), 'manifest')
html = decode(next(iter(manifest.values()))).decode()
assets = script(html, 'manifest')
template = script(html, 'template')
reference_dir = ROOT / '.artifacts/reference'
reference_dir.mkdir(parents=True, exist_ok=True)
for i, item in enumerate(manifest.values()):
    source = decode(item).decode()
    reference = script(source, 'template')
    reference = re.sub(r'<script\b[^>]*>.*?</script>', '', reference, flags=re.S | re.I)
    for key, asset in script(source, 'manifest').items():
        if asset.get('mime') == 'text/javascript':
            continue
        encoded = base64.b64encode(decode(asset)).decode()
        reference = reference.replace(key, f"data:{asset['mime']};base64,{encoded}")
    reference = reference.replace('sc-camel-view-box', 'viewBox')
    reference = static_template(reference)
    (reference_dir / f'reference-{i}.html').write_text(reference)

if '--references-only' in sys.argv:
    print(f'Extracted {len(manifest)} self-contained reference templates.')
    sys.exit(0)

from fontTools.ttLib import TTFont

font_names = {
    'bd19f8cf-316a-410c-84be-be7478e2140e': 'MonaSans',
    '09f5243b-7976-4c2e-80ca-5a51f10f60cc': 'MonaSansExtended',
    'f580018e-9244-4feb-b7d2-b78457d1f6da': 'JetBrainsMono',
    '18b08362-b952-4c16-95dd-84a3f2c8c093': 'JetBrainsMonoExtended',
}
for key, name in font_names.items():
    font = TTFont(io.BytesIO(decode(assets[key])))
    font.flavor = None
    font.save(ROOT / 'assets/fonts' / f'{name}.ttf')

# OKLCH to sRGB; colors are clipped only at the final display gamut boundary.
def color(value):
    if value.startswith('#'):
        return '0xFF' + value[1:].upper()
    values = [float(x) for x in re.findall(r'[0-9.]+', value)]
    light, chroma, hue = values[:3]
    alpha = values[3] if len(values) > 3 else 1
    a, b = chroma * math.cos(math.radians(hue)), chroma * math.sin(math.radians(hue))
    l = (light + .3963377774*a + .2158037573*b)**3
    m = (light - .1055613458*a - .0638541728*b)**3
    s = (light - .0894841775*a - 1.2914855480*b)**3
    rgb = [4.0767416621*l-3.3077115913*m+.2309699292*s,
           -1.2684380046*l+2.6097574011*m-.3413193965*s,
           -.0041960863*l-.7034186147*m+1.7076147010*s]
    def channel(v):
        v = 12.92*v if v <= .0031308 else 1.055*v**(1/2.4)-.055
        return round(min(1, max(0,v))*255)
    return '0x' + ''.join(f'{x:02X}' for x in [round(alpha*255), *map(channel,rgb)])

lines = ["// Extracted from design/food-ordering-shop.html by tool/extract_reference.py.",
         "import 'package:flutter/painting.dart';", '']
for mode in ['light', 'dark']:
    css = re.search(r'\[data-theme="' + mode + r'"\]\s*\{(.*?)\}', template, re.S).group(1)
    colors = {key: value for key,value in re.findall(r'--([\w-]+):\s*([^;]+);', css)
              if value.startswith('oklch(') or re.fullmatch('#[0-9a-f]{6}',value)}
    lines += [f'/// Exact {mode} semantic colors from the supplied prototype.', f'abstract final class Gabel{mode.title()} {{']
    for key,value in colors.items():
        name = re.sub(r'-([a-z0-9])', lambda m:m[1].upper(), key)
        lines += [f'  /// Prototype `{key}` token.', f'  static const {name} = Color({color(value)});']
    lines += ['}', '']
(ROOT / 'lib/theme/gabel_tokens.dart').write_text('\n'.join(lines))
print('Extracted four font subsets, light/dark tokens, and ten review templates.')
