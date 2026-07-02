// Copies packages/worm/docs/_assets -> docs_site/public/docs-assets so the
// site can serve images that docs/ pages reference relatively.
import { cpSync, existsSync, mkdirSync, rmSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const src = fileURLToPath(new URL('../../docs/_assets/', import.meta.url));
const dest = fileURLToPath(new URL('../public/docs-assets/', import.meta.url));

rmSync(dest, { recursive: true, force: true });
if (existsSync(src)) {
  mkdirSync(dest, { recursive: true });
  cpSync(src, dest, { recursive: true });
}
