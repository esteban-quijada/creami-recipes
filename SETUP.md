# Creami Recipes

Browse the recipes: **https://esteban-quijada.github.io/creami-recipes**

Extract Ninja Creami recipes from YouTube and TikTok videos using `yt-dlp` and `fabric-ai`.

## Prerequisites

- [yt-dlp](https://github.com/yt-dlp/yt-dlp) -- download subtitles/transcripts from YouTube
- [fabric-ai](https://github.com/danielmiessler/fabric) -- AI-powered text processing with patterns

Install both via Homebrew:

```bash
brew install yt-dlp fabric-ai
```

## Setup

Copy the custom Fabric pattern into your local patterns directory:

```bash
mkdir -p ~/.config/fabric/patterns/extract_creami_recipe
cp custom-fabric-pattern-extract-creami-recipe.md ~/.config/fabric/patterns/extract_creami_recipe/system.md
```

## Workflow

### 1. Download the transcript

Use `yt-dlp` to grab auto-generated subtitles from a YouTube video. The `--replace-in-metadata` flag swaps spaces for dashes in the filename:

```bash
yt-dlp --write-auto-sub --skip-download --replace-in-metadata "title" " " "-" <VIDEO_URL>
```

This produces a `.vtt` subtitle file in the current directory.

### 2. Extract recipes

Pipe the transcript into `fabric` with the custom pattern:

```bash
cat <transcript>.vtt | fabric --pattern extract_creami_recipe
```

This outputs structured Markdown for each recipe found in the video, including ingredients, preparation steps, freezing instructions, Creami program/spin settings, and mix-ins.

### 3. Save the output

To save the extracted recipes to a file:

```bash
cat <transcript>.vtt | fabric --pattern extract_creami_recipe > <recipe-name>.md
```

## One-liner

Download transcript and extract recipes in a single pipeline:

```bash
yt-dlp --write-auto-sub --skip-download -o - <VIDEO_URL> | fabric --pattern extract_creami_recipe
```
