import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { docsSchema } from '@astrojs/starlight/schema';

export const collections = {
  docs: defineCollection({
    // `base` resolves relative to the project root (docs_site/), so this is
    // packages/worm/docs. The second pattern excludes underscore-prefixed
    // directories (_assets, _templates, ...) the way docsLoader's [^_]
    // convention excludes underscore-prefixed files.
    loader: glob({
      base: '../docs',
      pattern: ['**/[^_]*.{md,mdx}', '!**/_*/**'],
    }),
    schema: docsSchema(),
  }),
};
