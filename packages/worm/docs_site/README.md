# Worm docs site

Thin Astro Starlight wrapper around the real docs in `../docs/`.
Edit content there; edit this package only for site behavior.

    npm install
    npm run dev        # http://localhost:4321/
    npm run build      # full build + link validation (what CI runs)
    npm run preview    # serve dist/ (Pagefind search works here, not in dev)

Emulate the deployed base path locally:

    DOCS_BASE=/beak npm run build && npm run preview
