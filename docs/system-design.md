# System Design

What the creami-recipes project is, how it's built, and how the pieces fit together.

---

## Overview

A recipe extraction pipeline and static website for Ninja Creami frozen dessert recipes. Recipes are extracted from YouTube and TikTok videos using `yt-dlp` and `fabric-ai`, then published to a GitHub Pages site.

Users browse recipes, view ingredients and steps, toggle between Standard (16 oz) and Deluxe (24 oz) portion sizes, and click through to source videos.

---

## Architecture Diagram

```
  YouTube / TikTok
        │
        ▼
  ┌───────────┐     ┌────────────────┐     ┌──────────────┐
  │  yt-dlp   │────►│  fabric-ai     │────►│  .md recipe  │
  │           │     │  (custom       │     │  file        │
  │ transcript│     │   pattern)     │     └──────┬───────┘
  │ or descr. │     └────────────────┘            │
  │ thumbnail │                          python3 parser
  └───────────┘                                   │
                                                  ▼
                                         ┌────────────────┐
                                         │ recipes.json   │
                                         └────────┬───────┘
                                                  │
                                           git push
                                                  │
                                                  ▼
                                         ┌────────────────┐
                                         │ GitHub Pages   │
                                         │                │
                                         │  index.html    │
                                         │  fetch() ──────┤
                                         │  recipes.json  │
                                         │  thumbnails/   │
                                         └────────────────┘
```

---

## Component Breakdown

### 1. Extraction Script — `extract-recipe.sh`

| Detail | Value |
|--------|-------|
| Language | Bash + Python 3 (inline) |
| Dependencies | yt-dlp, fabric-ai, python3 |

**What it does:**
1. Takes a video URL and source type (description or transcript)
2. Prompts for recipe name and category
3. Downloads video thumbnail via yt-dlp
4. Extracts description text or auto-generated subtitles via yt-dlp
5. Pipes content through fabric-ai with the `extract_creami_recipe` pattern
6. Saves structured Markdown to `recipes/<name>.md`
7. Parses the Markdown and appends the recipe to `recipes.json`

**Input handling:**
- Strips backslashes from URLs (common when copy-pasting from terminals)
- Auto-converts recipe name to lowercase with dashes
- Renames thumbnails from any extension (.webp, .image, .png) to .jpg

---

### 2. Fabric Pattern — `extract_creami_recipe`

| Detail | Value |
|--------|-------|
| Location (repo) | `custom-fabric-pattern-extract-creami-recipe.md` |
| Location (installed) | `~/.config/fabric/patterns/extract_creami_recipe/system.md` |

**Extracts from unstructured text:**
- Recipe name and base type (ice cream, sorbet, lite ice cream, etc.)
- Ingredients in dual-unit format: `Xg (Y cups/tbsp/tsp) ingredient`
- Numbered steps with inline measurements
- Notes and tips from the creator

**Output format:** Structured Markdown with `## Title`, `### Ingredients`, `### Steps`, `### Notes` sections.

---

### 3. Data Layer — `recipes.json`

Single JSON file containing all recipes grouped by category. Loaded by the website at runtime via `fetch()`.

**Schema:**

```json
[
  {
    "category": "Category Name",
    "recipes": [
      {
        "title": "Recipe Name",
        "videoId": "YouTube video ID (empty string if N/A)",
        "tiktok": "TikTok URL (empty string if N/A)",
        "thumbnail": "thumbnails/recipe-name.jpg",
        "desc": "One-sentence description",
        "baseType": "Lite Ice Cream",
        "ingredients": ["Xg (Y unit) ingredient"],
        "steps": ["Step description with inline measurements"],
        "notes": ["Optional tips"]
      }
    ]
  }
]
```

**Why a flat JSON file over a database:** No backend needed. GitHub Pages serves it as a static asset. The extraction script writes to it directly. Adding a recipe is a file change, not a database migration.

---

### 4. Website — `index.html`

| Detail | Value |
|--------|-------|
| Hosting | GitHub Pages |
| URL | https://esteban-quijada.github.io/creami-recipes |
| Framework | None (vanilla HTML/CSS/JS) |
| Data source | `recipes.json` (fetched at load) |
| Font | Inter (Google Fonts) |

**Features:**
- Sidebar with recipe list grouped by category and search
- Recipe view with ingredients (checkboxes), numbered steps, and notes
- Standard (16 oz) / Deluxe (24 oz) size toggle that scales all measurements
- Clickable thumbnail previews linking to source videos (YouTube or TikTok)
- YouTube videos use auto-generated thumbnails from `img.youtube.com`
- TikTok videos use locally downloaded thumbnails in `thumbnails/`
- Dark theme inspired by ElevenLabs design (deep background, gradient accents, Inter font)
- Mobile responsive (sidebar stacks above content on small screens)

**Scaling logic:**
- Deluxe pint (24 oz) = 1.5x Standard pint (16 oz)
- Scales gram values, volume measurements, Unicode fractions, and numeric ranges
- Applied to both ingredients and steps (inline measurements)

---

## Directory Structure

```
creami-recipes/
├── index.html                                  # Website (single-page app)
├── recipes.json                                # Recipe data (fetched by website)
├── extract-recipe.sh                           # Extraction pipeline script
├── custom-fabric-pattern-extract-creami-recipe.md  # Fabric pattern (git-tracked copy)
├── README.md
├── docs/
│   ├── system-design.md
│   ├── architecture-decisions.md
│   └── tooling-dependencies.md
├── recipes/                                    # Extracted recipe Markdown files
│   ├── cake-batter-recipe.md
│   ├── pb-caramel-protein-ice-cream.md
│   ├── strawberry-protein-ice-cream.md
│   └── perfect-oreo-ice-cream.md
└── thumbnails/                                 # Video thumbnail images
    ├── cake-batter-protein-ice-cream.jpg
    ├── pb-caramel-protein-ice-cream.jpg
    ├── strawberry-protein-ice-cream.jpg
    └── perfect-oreo-ice-cream.jpg
```

---

## Workflow

### Adding a new recipe

```bash
./extract-recipe.sh "<video-url>" <description|transcript>
git add recipes.json recipes/ thumbnails/
git commit -m "Add <recipe-name>"
git push
```

The website updates automatically on GitHub Pages after push.
