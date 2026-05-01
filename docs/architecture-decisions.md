# Architecture Decision Records (ADRs)

Each ADR documents a significant technical choice, what alternatives were considered, and why the current approach was selected. Decisions are numbered and dated for reference.

---

## ADR-001: Static site over a framework (React, Next.js, Astro)

**Date:** 2026-04-30
**Status:** Accepted

### Context
Need a website to display Creami recipes. The site has no user accounts, no forms, no dynamic server-side content — just recipe display with client-side interactivity (search, scaling).

### Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| **Vanilla HTML/CSS/JS** | Zero build step, free GitHub Pages hosting, instant deploys | No component reuse, scaling logic is inline |
| **React + Vite** | Component model, ecosystem | Build step, node_modules, overkill for a recipe viewer |
| **Next.js** | SSR/SSG, file-based routing | Server needed for SSR, heavy for static content |
| **Astro** | Static-first, .md support, partial hydration | Build step, new tooling, learning curve |
| **Hugo/Jekyll** | Built for static sites, Markdown-native | Templating languages, theme lock-in |

### Decision
Vanilla HTML/CSS/JS in a single `index.html`. The site is a recipe viewer with search and a scaling toggle — all achievable without a framework. No build step means the development loop is edit → refresh → done.

### Consequences
- Zero dependencies, zero build step
- All CSS, JS, and HTML in one file — simple but harder to maintain at scale
- If the site grows to need multiple pages or complex interactivity, migrate to Astro (reads .md files natively)

---

## ADR-002: recipes.json over hardcoded JS data

**Date:** 2026-05-01
**Status:** Accepted

### Context
Recipes were initially hardcoded in the `db` array inside `index.html`. Adding a recipe required editing HTML. The extraction script (`extract-recipe.sh`) couldn't update the site automatically.

### Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| **Hardcoded JS array (original)** | No fetch needed, works on file:// | Manual editing, script can't auto-update |
| **recipes.json (chosen)** | Script writes directly, data separated from presentation | Requires fetch(), doesn't work on file:// (needs a server or GitHub Pages) |
| **Individual .md files per recipe** | Most git-friendly, easy diffs | Requires a build step or runtime Markdown parser |
| **SQLite / database** | Query support, relational | Needs a backend, can't host on GitHub Pages |

### Decision
Single `recipes.json` file fetched at load time. The extraction script appends to it via an inline Python parser. Data is separated from presentation without introducing a build step.

### Consequences
- `extract-recipe.sh` can add recipes end-to-end without manual intervention
- Local development requires a local server (`python3 -m http.server`) since `fetch()` doesn't work on `file://` URLs
- Single JSON file could get large eventually — not a concern at current scale
- Recipe `.md` files in `recipes/` serve as human-readable backups

---

## ADR-003: fabric-ai with custom pattern over manual transcription

**Date:** 2026-04-30
**Status:** Accepted

### Context
Need to extract structured recipes from unstructured video transcripts and descriptions. Transcripts contain filler words, tangents, and non-recipe content mixed in with ingredient lists and instructions.

### Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| **fabric-ai custom pattern** | Reusable, consistent output format, handles messy input | Depends on LLM quality, may hallucinate measurements |
| **Manual extraction** | Perfect accuracy | Slow, tedious, doesn't scale |
| **Custom Python script with regex** | No LLM dependency | Brittle, can't handle natural language variation |
| **ChatGPT/Claude copy-paste** | Flexible | Manual, no automation, inconsistent output format |

### Decision
fabric-ai with a custom `extract_creami_recipe` pattern. The pattern enforces a consistent output structure (dual-unit ingredients, numbered steps with inline measurements) while handling the variability of natural language input.

### Consequences
- Output quality depends on the LLM model fabric-ai is configured to use
- The pattern file is git-tracked (`custom-fabric-pattern-extract-creami-recipe.md`) and must be manually copied to `~/.config/fabric/patterns/` on new machines
- Measurements should be spot-checked — LLM may approximate unit conversions

---

## ADR-004: yt-dlp for content extraction over browser-based approaches

**Date:** 2026-04-30
**Status:** Accepted

### Context
Need to get text content (descriptions, transcripts) and thumbnails from YouTube and TikTok videos for recipe extraction.

### Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| **yt-dlp** | Supports YouTube + TikTok, CLI-friendly, downloads subs/descriptions/thumbnails | Depends on platform not blocking, no official API |
| **YouTube Data API** | Official, reliable | API key required, no transcript access, YouTube only |
| **Browser extension** | Visual, easy copy-paste | Manual, not scriptable |
| **Whisper (audio transcription)** | Works when no subtitles exist | Requires video download, slower, extra dependency |

### Decision
yt-dlp for both platforms. It handles subtitles, descriptions, and thumbnails in a single tool, and integrates cleanly into a bash pipeline.

### Consequences
- Works for both YouTube and TikTok without separate tools
- Auto-generated subtitles may have errors (no punctuation, misspellings)
- TikTok subtitle availability depends on the creator enabling captions
- If subtitles aren't available, Whisper is the fallback (not yet integrated)

---

## ADR-005: Dual-unit ingredient format (grams + volume)

**Date:** 2026-04-30
**Status:** Accepted

### Context
Creami recipes benefit from precise measurements (especially for emulsifiers like xanthan gum). Some users have kitchen scales, others only have measuring cups/spoons.

### Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| **Grams only** | Precise, unambiguous | Not accessible to users without a scale |
| **Volume only (cups/tbsp)** | Familiar to US home cooks | Imprecise for small quantities, varies by ingredient density |
| **Dual-unit: grams (volume)** | Accessible to both audiences, precise and familiar | Verbose, conversion may be approximate |

### Decision
Dual-unit format with grams first: `615g (about 2½ cups) 2% milk`. The fabric pattern instructs the LLM to convert when only one unit is provided.

### Consequences
- Ingredients and steps include both formats, making recipes longer but more usable
- Unit conversions are approximate — the pattern says "use standard conversions"
- The size scaling logic must handle both gram values and volume values independently

---

## ADR-006: Client-side scaling over pre-computed recipe variants

**Date:** 2026-04-30
**Status:** Accepted

### Context
The Ninja Creami comes in two sizes: Standard (16 oz pint) and Deluxe (24 oz pint). Recipes need to be scalable between the two sizes (1.5x factor).

### Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| **Client-side scaling (chosen)** | Single recipe entry, toggle is instant, no data duplication | Complex regex parsing, edge cases with fractions |
| **Two entries per recipe** | Simple rendering, no parsing needed | Data duplication, manual effort for every recipe |
| **Scale factor in recipes.json** | Data-driven | Still need client-side math |

### Decision
Client-side JavaScript scales measurements in real-time using regex. A toggle switches between Standard (1x) and Deluxe (1.5x). Scaling applies to both the ingredients list and the steps (which contain inline measurements).

### Consequences
- Scaling handles: gram values, volume values, Unicode fractions, numeric ranges (e.g., 10–15g)
- Fraction rendering uses Unicode characters (½, ⅓, ¾, etc.) for clean display
- Some edge cases may produce awkward fractions — acceptable for a recipe context
- The scaling factor is hardcoded (1.5x) since there are only two Creami sizes
