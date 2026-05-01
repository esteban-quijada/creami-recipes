# Tooling & Dependencies

Tools and services used to build, extract, and deploy recipes. The website itself has zero runtime dependencies — these exist for the extraction pipeline, development workflow, and hosting.

For technology choices and rationale, see [architecture-decisions.md](architecture-decisions.md).

---

## Currently In Use

### Extraction Pipeline

| Tool | Install | What it does | Where it's used |
|------|---------|-------------|-----------------|
| yt-dlp | `brew install yt-dlp` | Downloads subtitles, descriptions, and thumbnails from YouTube and TikTok | `extract-recipe.sh` |
| fabric-ai | `brew install fabric-ai` | LLM-powered text processing with reusable patterns | `extract-recipe.sh` |
| python3 | System / Homebrew | Parses extracted Markdown and updates `recipes.json` | `extract-recipe.sh` (inline script) |

### Website

| Tool | Version | What it does | Where it's used |
|------|---------|-------------|-----------------|
| Inter font | — | UI typeface (loaded from Google Fonts) | `index.html` (CSS @import) |

No build tools, no npm, no bundler. The website is a single `index.html` that fetches `recipes.json`.

### Hosting & Deployment

| Service | What it does | Configuration |
|---------|-------------|---------------|
| GitHub Pages | Static site hosting | Enabled on repo settings, serves from main branch root |
| GitHub | Source control | `https://github.com/esteban-quijada/creami-recipes` |

### Development

| Tool | What it does | When it's needed |
|------|-------------|-----------------|
| `python3 -m http.server` | Local dev server | Testing locally (fetch() requires HTTP, not file://) |
| Any text editor | Edit recipes.json or index.html | Manual recipe adjustments |

---

## Optional / Fallback

| Tool | Install | What it does | When to use |
|------|---------|-------------|-------------|
| ffmpeg | `brew install ffmpeg` | Converts thumbnail formats (yt-dlp uses it for --convert-thumbnails) | Not required — the script manually renames .webp/.image to .jpg |
| Whisper | `pip install openai-whisper` | Audio-to-text transcription | When a video has no auto-generated subtitles |

---

## Fabric Pattern Setup

The custom fabric pattern is git-tracked but must be installed to the local fabric config directory:

```bash
mkdir -p ~/.config/fabric/patterns/extract_creami_recipe
cp custom-fabric-pattern-extract-creami-recipe.md ~/.config/fabric/patterns/extract_creami_recipe/system.md
```

This is a one-time setup per machine. The pattern is not auto-installed.

---

## External Service Dependencies

| Service | What it does | Failure impact |
|---------|-------------|----------------|
| YouTube | Source of recipe videos and transcripts | Can't extract new recipes from YouTube |
| TikTok | Source of recipe videos and descriptions | Can't extract new recipes from TikTok |
| Google Fonts (fonts.googleapis.com) | Serves Inter font | Website falls back to system sans-serif |
| img.youtube.com | YouTube video thumbnails | YouTube recipe thumbnails don't load (TikTok unaffected — thumbnails are local) |
| GitHub Pages | Serves the website | Site is down (recipes.json and index.html still in repo) |

---

## Version Pinning Status

| Tool | Pinned? | Notes |
|------|---------|-------|
| yt-dlp | No | Installed via Homebrew, updates with `brew upgrade` |
| fabric-ai | No | Installed via Homebrew |
| python3 | No | System Python or Homebrew |
| Inter font | No | Loaded from Google Fonts CDN (latest) |

No dependencies are pinned. This is acceptable because:
- The extraction script runs locally and manually (not in CI)
- The website has zero runtime dependencies beyond a browser
- Breaking changes in yt-dlp or fabric-ai would only affect new recipe extraction, not existing recipes
