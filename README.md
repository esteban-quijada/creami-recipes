# Creami Recipes

Browse the recipes: **https://esteban-quijada.github.io/creami-recipes**

A collection of Ninja Creami recipes extracted from YouTube and TikTok videos using [yt-dlp](https://github.com/yt-dlp/yt-dlp) and [fabric-ai](https://github.com/danielmiessler/fabric), served as a static site on GitHub Pages.

## Quick Start

```bash
# Install dependencies
brew install yt-dlp fabric-ai

# Install the custom fabric pattern (one-time setup)
mkdir -p ~/.config/fabric/patterns/extract_creami_recipe
cp custom-fabric-pattern-extract-creami-recipe.md ~/.config/fabric/patterns/extract_creami_recipe/system.md

# Extract a recipe
./extract-recipe.sh "https://www.youtube.com/watch?v=VIDEO_ID" transcript
# or
./extract-recipe.sh "https://www.tiktok.com/@user/video/ID" description

# Commit and deploy
git add recipes.json recipes/ thumbnails/
git commit -m "Add recipe-name"
git push
```

The website updates automatically on GitHub Pages after push.

## Local Development

The site fetches `recipes.json` at runtime, which requires an HTTP server (browsers block `fetch()` on `file://` URLs).

```bash
# Start a local server
cd creami-recipes
python3 -m http.server 8080

# Open in browser
open http://localhost:8080

# Edit index.html, save, refresh browser to see changes
# Ctrl+C to stop the server when done
```

## How It Works

```
YouTube / TikTok video
        |
    yt-dlp (transcript or description + thumbnail)
        |
    fabric-ai (custom extract_creami_recipe pattern)
        |
    recipes/<name>.md + recipes.json
        |
    git push -> GitHub Pages
```

The extraction script (`extract-recipe.sh`) handles the full pipeline: downloads content and thumbnail, extracts a structured recipe via fabric-ai, saves the `.md` file, and appends to `recipes.json` which the website fetches at load time.

## Website Features

- Light theme (ElevenLabs-inspired) with recipe sidebar, search, and category grouping
- Theme picker with six flavor-named color palettes (Mango, Mint, Blueberry, Strawberry, Grape, Pistachio)
- Ingredients with checkboxes and dual-unit format (grams + volume)
- Numbered steps with inline measurements
- Standard (16 oz) / Deluxe (24 oz) size toggle that scales all quantities
- Clickable video thumbnail previews (YouTube and TikTok)
- Mobile responsive

## Docs

- [System Design](docs/system-design.md) -- architecture, components, directory structure
- [Architecture Decisions](docs/architecture-decisions.md) -- ADRs for key technical choices
- [Tooling & Dependencies](docs/tooling-dependencies.md) -- tools, services, setup requirements
