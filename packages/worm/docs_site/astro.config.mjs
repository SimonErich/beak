// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import mermaid from 'astro-mermaid';
import starlightLlmsTxt from 'starlight-llms-txt';
import { fileURLToPath } from 'node:url';
import { remarkDocsLinks } from './src/plugins/remark-docs-links.mjs';

// Content lives OUTSIDE this project, in packages/worm/docs/.
const docsDir = fileURLToPath(new URL('../docs', import.meta.url));

// --- GitHub Pages URL derivation -----------------------------------------
// In GitHub Actions, GITHUB_REPOSITORY is "<owner>/<repo>" (always set).
// Project site => https://<owner>.github.io/<repo>/ with base "/<repo>".
// Locally both are unset, so dev/preview serve from "/".
// Custom domain later? Set DOCS_SITE (full origin) and DOCS_BASE=/ in the
// workflow env and nothing else changes.
const ghRepo = process.env.GITHUB_REPOSITORY;
const [ghOwner, ghName] = ghRepo ? ghRepo.split('/') : [];
const isUserSite = ghName?.endsWith('.github.io') ?? false;
const site =
  process.env.DOCS_SITE ??
  (ghOwner
    ? isUserSite
      ? `https://${ghName}`
      : `https://${ghOwner}.github.io`
    : 'https://example.github.io'); // placeholder; starlight-llms-txt requires `site`
const base = process.env.DOCS_BASE ?? (ghRepo && !isUserSite ? `/${ghName}` : '/');

export default defineConfig({
  site,
  base,
  vite: {
    resolve: {
      alias: [
        // .mdx pages live in ../docs, outside this project, so bare imports
        // don't resolve from there. Pin the one specifier they need to this
        // package's own dependency. Exact match only: a prefix alias would
        // hijack Starlight's internal subpath imports.
        {
          find: /^@astrojs\/starlight\/components$/,
          replacement: fileURLToPath(import.meta.resolve('@astrojs/starlight/components')),
        },
      ],
    },
  },
  markdown: {
    // Rewrites relative ./page.md links (and _assets images) from ../docs
    // into final site URLs. Runs before integration-added remark plugins,
    // so the links validator sees the rewritten URLs.
    remarkPlugins: [[remarkDocsLinks, { docsDir, base }]],
  },
  integrations: [
    // ORDER MATTERS: astro-mermaid must register before Starlight so its
    // remark plugin claims ```mermaid fences before Expressive Code renders
    // them as plain code blocks.
    mermaid({ autoTheme: true }),
    starlight({
      title: 'Worm',
      description:
        'A type-safe, Eloquent-inspired ORM for server-side Dart. The bird has to eat something.',
      favicon: '/favicon.svg',
      social: [
        {
          icon: 'github',
          label: 'GitHub',
          // TODO(repo): replace fallback once the GitHub repo exists.
          href: `https://github.com/${ghRepo ?? 'OWNER/REPO'}`,
        },
      ],
      // Starlight's own remark pipeline (asides, heading anchors, ...) only
      // processes srcDir content by default. This opts ../docs in.
      markdown: {
        processedDirs: [docsDir],
      },
      customCss: ['./src/styles/custom.css'],
      // Curated order. Only Start Here and the Tutorial open on first visit;
      // Starlight auto-expands whichever group holds the current page.
      // The Cheatsheet is pinned at the top for humans and agents alike.
      sidebar: [
        {
          label: 'Cheatsheet',
          link: '/reference/cheatsheet/',
          badge: { text: 'fast', variant: 'tip' },
        },
        {
          label: 'Start here',
          collapsed: false,
          items: [
            'start-here/what-is-worm',
            'start-here/why-worm',
            'start-here/installation',
            'start-here/quickstart',
            'start-here/configuration',
          ],
        },
        {
          label: 'Tutorial: Nestwatch',
          collapsed: false,
          items: [
            'tutorial/overview',
            'tutorial/01-hatching-the-project',
            'tutorial/02-your-first-model',
            'tutorial/03-sightings-and-relations',
            'tutorial/04-seeding-a-fake-flock',
            'tutorial/05-queries-that-sing',
            'tutorial/06-safety-nets-and-wrap-up',
          ],
        },
        {
          label: 'Models',
          collapsed: true,
          items: [
            'models/defining-models',
            'models/code-generation',
            'models/saving-and-updating',
            'models/validation',
            'models/mass-assignment',
            'models/lifecycle-hooks-and-observers',
            'models/casts',
            'models/serialization',
            'models/soft-deletes',
            'models/factories',
            'models/repository-pattern',
          ],
        },
        {
          label: 'Queries',
          collapsed: true,
          items: [
            'queries/query-basics',
            'queries/advanced-queries',
            'queries/pagination',
            'queries/scopes',
          ],
        },
        {
          label: 'Relations',
          collapsed: true,
          items: [
            'relations/defining-relations',
            'relations/eager-loading',
            'relations/working-with-relations',
            'relations/polymorphic-relations',
          ],
        },
        {
          label: 'Database and schema',
          collapsed: true,
          items: [
            'database/migrations',
            'database/schema-builder',
            'database/migrations-in-depth',
            'database/seeding',
            'database/transactions',
            'database/multiple-connections',
          ],
        },
        {
          label: 'Database drivers',
          collapsed: true,
          items: [
            'drivers/choosing-a-database',
            'drivers/how-drivers-work',
            'drivers/in-memory',
            'drivers/sqlite',
            'drivers/postgresql',
            'drivers/mysql',
            'drivers/mongodb',
          ],
        },
        {
          label: 'Guides',
          collapsed: true,
          items: [
            'guides/testing',
            'guides/logging-and-debugging',
            'guides/performance',
            'guides/security',
            'guides/strict-mode',
            'guides/production',
            'guides/ai-agents',
          ],
        },
        {
          label: 'Reference',
          collapsed: true,
          items: [
            'reference/cheatsheet',
            'reference/cli-commands',
            'reference/worm-runtime',
            'reference/configuration-options',
            'reference/operators-and-fields',
            'reference/annotations',
            'reference/naming-conventions',
            'reference/adapter-api',
            'reference/exceptions',
            'reference/glossary',
          ],
        },
        {
          label: 'Contributing',
          collapsed: true,
          items: [
            'contributing/contributing',
            'contributing/architecture',
            'contributing/writing-a-database-driver',
          ],
        },
      ],
      // Link validation happens at the SOURCE level in scripts/check-links.mjs
      // (wired into prebuild). starlight-links-validator cannot be used: it
      // keys pages by paths relative to src/content/docs and mis-keys every
      // page loaded from ../docs, failing all internal links.
      plugins: [
        starlightLlmsTxt({
          // Put the agent-facing pages first in /llms.txt and /llms-full.txt.
          promote: ['reference/cheatsheet', 'reference/cli-commands', 'guides/ai-agents', 'index'],
        }),
      ],
    }),
  ],
});
