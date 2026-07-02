// Source-level link checker for packages/worm/docs.
//
// Validates the markdown SOURCE, which is exactly what authors edit and what
// GitHub renders. The remark rewrite (src/plugins/remark-docs-links.mjs) maps
// these same links onto site URLs deterministically, so source-valid means
// site-valid. (starlight-links-validator cannot be used here: it keys pages
// by paths relative to src/content/docs and breaks for out-of-srcDir content.)
//
// Rules enforced:
// - Relative links must point at an existing file under docs/.
// - Links to .md/.mdx pages may carry #anchors; the anchor must match a
//   heading in the target file (github-slugger, same as the site).
// - Site-internal absolute links ("/queries/") are forbidden: they are dead
//   on GitHub and break under a non-root base path. Use relative ./page.md.
// - External links (http/https/mailto/...) are not checked.
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import GithubSlugger from 'github-slugger';

const docsDir = fileURLToPath(new URL('../../docs/', import.meta.url));

function walk(dir) {
  const out = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (!entry.name.startsWith('_') && entry.name !== 'node_modules') out.push(...walk(full));
    } else if (/\.(md|mdx)$/i.test(entry.name)) {
      out.push(full);
    }
  }
  return out;
}

// Markdown links/images + mdx href/src attributes. Good enough for docs
// written under the authoring contract (no reference-style links needed,
// but they are covered too).
const LINK_RES = [
  /!?\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g, // [t](url) / ![a](url)
  /^\[[^\]]+\]:\s*(\S+)/gm, // [ref]: url
  /(?:href|src)=(?:"([^"]+)"|'([^']+)')/g, // mdx attributes
];

function headingsOf(file) {
  const slugger = new GithubSlugger();
  const text = readFileSync(file, 'utf8').replace(/^---\n[\s\S]*?\n---\n/, '');
  const ids = new Set();
  for (const m of text.matchAll(/^#{1,6}\s+(.+?)\s*#*\s*$/gm)) {
    // Strip inline code/emphasis/links the way GitHub does before slugging.
    const plain = m[1]
      .replace(/`([^`]*)`/g, '$1')
      .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
      .replace(/[*_]/g, '');
    ids.add(slugger.slug(plain));
  }
  return ids;
}

const headingCache = new Map();
const errors = [];
const files = walk(docsDir);

for (const file of files) {
  const rel = path.relative(docsDir, file);
  const raw = readFileSync(file, 'utf8');
  // Ignore links inside fenced code blocks.
  const text = raw.replace(/^```[\s\S]*?^```/gm, (block) => block.replace(/\S/g, ' '));
  const fromDir = path.dirname(file);

  const urls = [];
  for (const re of LINK_RES) {
    for (const m of text.matchAll(re)) urls.push(m[1] ?? m[2]);
  }

  for (const url of urls) {
    if (!url || url.startsWith('#')) continue;
    if (/^[a-z][a-z0-9+.-]*:/i.test(url)) continue; // external scheme
    if (url.startsWith('{')) continue; // JSX expression, not a string literal
    if (url.startsWith('/')) {
      errors.push(`${rel}: absolute link "${url}" — use a relative ./page.md link instead`);
      continue;
    }
    const [target, hash] = url.split('#');
    if (!target) continue;
    const resolvedTarget = path.resolve(fromDir, decodeURI(target));
    if (!path.relative(docsDir, resolvedTarget).startsWith('..')) {
      let stat;
      try {
        stat = readFileSync(resolvedTarget);
      } catch {
        errors.push(`${rel}: broken link "${url}" (no such file)`);
        continue;
      }
      if (hash && /\.mdx?$/i.test(target)) {
        if (!headingCache.has(resolvedTarget)) headingCache.set(resolvedTarget, headingsOf(resolvedTarget));
        if (!headingCache.get(resolvedTarget).has(hash)) {
          errors.push(`${rel}: broken anchor "${url}" (no heading #${hash} in target)`);
        }
      }
      if (stat && /\.mdx?$/i.test(target) === false && !target.includes('_assets/')) {
        errors.push(`${rel}: link "${url}" targets a non-page file outside _assets/`);
      }
    } else {
      errors.push(`${rel}: link "${url}" escapes docs/ — use a full GitHub URL for source files`);
    }
  }
}

if (errors.length > 0) {
  console.error(`check-links: ${errors.length} problem(s) in ${files.length} files\n`);
  for (const e of errors) console.error(`  ${e}`);
  process.exit(1);
}
console.log(`check-links: OK (${files.length} files)`);
