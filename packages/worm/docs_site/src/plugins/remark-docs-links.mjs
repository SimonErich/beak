/**
 * Rewrites relative links in markdown under packages/worm/docs so the same
 * files read correctly on GitHub AND on the deployed site.
 *
 *   ./queries.md            -> {base}/queries/
 *   ../relations/index.md   -> {base}/relations/
 *   ./queries.md#pagination -> {base}/queries/#pagination
 *   ../_assets/erd.png      -> {base}/docs-assets/erd.png
 *
 * Anything absolute (/x, https://x), protocol-ish (mailto:), same-page (#x),
 * or resolving outside docs/ is left untouched. starlight-links-validator
 * then flags leftovers at build time.
 */
import path from 'node:path';
import { visit } from 'unist-util-visit';

const MD_RE = /\.mdx?$/i;
const ASSET_RE = /\.(png|jpe?g|gif|svg|webp|avif|mp4|webm|pdf)$/i;

export function remarkDocsLinks({ docsDir, base }) {
  const root = path.resolve(docsDir);
  const prefix = base.endsWith('/') ? base : `${base}/`;

  return (tree, file) => {
    const filePath = file.path ?? file.history?.[0];
    if (!filePath) return;
    const abs = path.resolve(filePath);
    if (abs !== root && !abs.startsWith(root + path.sep)) return; // not a docs/ page
    const fromDir = path.dirname(abs);

    const rewrite = (url) => {
      if (
        !url ||
        url.startsWith('#') ||
        url.startsWith('/') ||
        /^[a-z][a-z0-9+.-]*:/i.test(url) // https:, mailto:, tel:, ...
      ) {
        return url;
      }
      const [target, hash = ''] = url.split('#');
      if (!target) return url;
      const resolved = path.resolve(fromDir, decodeURI(target));
      const rel = path.relative(root, resolved).split(path.sep).join('/');
      if (rel.startsWith('..')) return url; // escapes docs/ — leave it for the validator

      if (MD_RE.test(rel)) {
        let slug = rel.replace(MD_RE, '');
        if (slug === 'index') slug = '';
        else if (slug.endsWith('/index')) slug = slug.slice(0, -'/index'.length);
        return `${prefix}${slug ? `${slug}/` : ''}${hash ? `#${hash}` : ''}`;
      }
      if (ASSET_RE.test(rel) && rel.startsWith('_assets/')) {
        return `${prefix}docs-assets/${rel.slice('_assets/'.length)}`;
      }
      return url;
    };

    visit(tree, ['link', 'image', 'definition'], (node) => {
      node.url = rewrite(node.url);
    });

    // MDX components too: <LinkCard href="./page.md" />, <img src="../_assets/x.png" />
    visit(tree, ['mdxJsxFlowElement', 'mdxJsxTextElement'], (node) => {
      for (const attr of node.attributes ?? []) {
        if (
          attr.type === 'mdxJsxAttribute' &&
          (attr.name === 'href' || attr.name === 'src') &&
          typeof attr.value === 'string'
        ) {
          attr.value = rewrite(attr.value);
        }
      }
    });
  };
}
