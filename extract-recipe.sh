#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: ./extract-recipe.sh <video-url> <description|transcript>"
    echo ""
    echo "Examples:"
    echo "  ./extract-recipe.sh https://www.tiktok.com/@user/video/123 description"
    echo "  ./extract-recipe.sh https://www.youtube.com/watch?v=abc transcript"
    exit 1
}

[ $# -lt 2 ] && usage

# Strip backslashes from URL (e.g. \? \= from copy-pasted URLs)
URL=$(echo "$1" | tr -d '\\')
SOURCE="$2"

if [[ "$SOURCE" != "description" && "$SOURCE" != "transcript" ]]; then
    echo "Error: second argument must be 'description' or 'transcript'"
    usage
fi

# Detect platform
if [[ "$URL" == *"tiktok"* ]]; then
    PLATFORM="tiktok"
elif [[ "$URL" == *"youtube"* || "$URL" == *"youtu.be"* ]]; then
    PLATFORM="youtube"
else
    echo "Error: URL must be from YouTube or TikTok"
    exit 1
fi

# Prompt for recipe name
read -rp "Recipe name (e.g. cake-batter-protein-ice-cream): " RECIPE_NAME
if [ -z "$RECIPE_NAME" ]; then
    echo "Error: recipe name cannot be empty"
    exit 1
fi
# Convert spaces to dashes and lowercase
RECIPE_NAME=$(echo "$RECIPE_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

# Prompt for category
read -rp "Category (e.g. Protein Ice Cream): " CATEGORY
if [ -z "$CATEGORY" ]; then
    CATEGORY="Uncategorized"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RECIPES_DIR="$SCRIPT_DIR/recipes"
THUMBS_DIR="$SCRIPT_DIR/thumbnails"
RECIPES_JSON="$SCRIPT_DIR/recipes.json"
mkdir -p "$RECIPES_DIR" "$THUMBS_DIR"

# Download thumbnail
echo "Downloading thumbnail..."
yt-dlp --write-thumbnail --skip-download \
    -o "$THUMBS_DIR/$RECIPE_NAME" "$URL" 2>/dev/null || true

# Rename thumbnail to .jpg regardless of original extension (.image, .webp, .png, etc.)
THUMB_PATH=""
THUMB_JPG="$THUMBS_DIR/$RECIPE_NAME.jpg"
for ext in image webp png jpeg jpg; do
    THUMB_FILE="$THUMBS_DIR/$RECIPE_NAME.$ext"
    if [ -f "$THUMB_FILE" ] && [ "$THUMB_FILE" != "$THUMB_JPG" ]; then
        mv "$THUMB_FILE" "$THUMB_JPG"
        break
    fi
done
if [ -f "$THUMB_JPG" ]; then
    THUMB_PATH="thumbnails/$RECIPE_NAME.jpg"
fi

# Extract content
echo "Extracting $SOURCE..."
if [ "$SOURCE" = "description" ]; then
    CONTENT=$(yt-dlp --print description "$URL")
else
    TMP_DIR=$(mktemp -d)
    yt-dlp --write-auto-sub --sub-lang "en" --skip-download \
        -o "$TMP_DIR/$RECIPE_NAME" "$URL"
    SUB_FILE=$(find "$TMP_DIR" -name "*.vtt" -o -name "*.srt" | head -1)
    if [ -z "$SUB_FILE" ]; then
        echo "Error: no subtitles found for this video"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    CONTENT=$(cat "$SUB_FILE")
    rm -rf "$TMP_DIR"
fi

# Run through fabric
echo "Extracting recipe with fabric..."
RECIPE_FILE="$RECIPES_DIR/$RECIPE_NAME.md"
echo "$CONTENT" | fabric-ai --pattern extract_creami_recipe > "$RECIPE_FILE"

# Build metadata footer in .md
{
    echo ""
    echo "---"
    echo "source: $URL"
    echo "platform: $PLATFORM"
    echo "extracted_from: $SOURCE"
    echo "date: $(date +%Y-%m-%d)"
    if [ "$PLATFORM" = "youtube" ]; then
        VIDEO_ID=$(echo "$URL" | sed -n 's/.*[?&]v=\([^&]*\).*/\1/p')
        [ -z "$VIDEO_ID" ] && VIDEO_ID=$(echo "$URL" | sed -n 's|.*youtu\.be/\([^?]*\).*|\1|p')
        [ -n "$VIDEO_ID" ] && echo "video_id: $VIDEO_ID"
    fi
    [ -n "$THUMB_PATH" ] && echo "thumbnail: $THUMB_PATH"
    echo "---"
} >> "$RECIPE_FILE"

# Parse the .md and add to recipes.json
echo "Adding to recipes.json..."

VIDEO_ID=""
if [ "$PLATFORM" = "youtube" ]; then
    VIDEO_ID=$(echo "$URL" | sed -n 's/.*[?&]v=\([^&]*\).*/\1/p')
    [ -z "$VIDEO_ID" ] && VIDEO_ID=$(echo "$URL" | sed -n 's|.*youtu\.be/\([^?]*\).*|\1|p')
fi

TIKTOK_URL=""
if [ "$PLATFORM" = "tiktok" ]; then
    TIKTOK_URL="$URL"
fi

# Use python3 to parse the markdown and update recipes.json
python3 << PYEOF
import json, re, sys

md_path = "$RECIPE_FILE"
json_path = "$RECIPES_JSON"
category = "$CATEGORY"
video_id = "$VIDEO_ID"
tiktok = "$TIKTOK_URL"
thumbnail = "$THUMB_PATH"

with open(md_path, "r") as f:
    md = f.read()

# Remove metadata footer
md = re.split(r"\n---\n", md)[0]

# Parse title
title_match = re.search(r"^##\s+(.+)", md, re.MULTILINE)
title = title_match.group(1).strip() if title_match else "$RECIPE_NAME"

# Parse base type
base_match = re.search(r"\*\*Base type:\*\*\s*(.+)", md)
base_type = base_match.group(1).strip() if base_match else ""

# Parse description (line after base type, before ### Ingredients)
desc = ""
desc_match = re.search(r"\*\*Base type:\*\*[^\n]*\n\n(.+?)(?=\n\n###|\n###)", md, re.DOTALL)
if desc_match:
    desc = desc_match.group(1).strip()

# Parse ingredients
ingredients = []
ing_match = re.search(r"### Ingredients\s*\n(.*?)(?=\n###|\n---|\Z)", md, re.DOTALL)
if ing_match:
    for line in ing_match.group(1).strip().split("\n"):
        line = line.strip()
        if line.startswith("- "):
            ingredients.append(line[2:].strip())

# Parse steps
steps = []
steps_match = re.search(r"### Steps\s*\n(.*?)(?=\n###|\n---|\Z)", md, re.DOTALL)
if steps_match:
    for line in steps_match.group(1).strip().split("\n"):
        line = line.strip()
        step = re.sub(r"^\d+\.\s*", "", line)
        if step:
            steps.append(step)

# Parse macros (single or multiple variants)
macros = []
macros_match = re.search(r"### Macros\s*\n(.*?)(?=\n###|\n---|\Z)", md, re.DOTALL)
if macros_match:
    macros_text = macros_match.group(1)
    # Check for variant sub-headings (#### Label)
    variants = re.split(r"\n####\s+", macros_text)
    if len(variants) > 1:
        # Multiple variants: first element is any text before the first ####
        for v in variants[1:]:
            lines = v.strip().split("\n")
            label = lines[0].strip()
            entry = {"label": label}
            block = "\n".join(lines[1:])
            for key in ["Calories", "Protein", "Fat", "Carbs", "Sugar"]:
                m = re.search(rf"\*\*{key}:\*\*\s*(\d+)", block)
                if m:
                    entry[key.lower()] = int(m.group(1))
            macros.append(entry)
    else:
        # Single variant
        entry = {"label": "Whole pint"}
        for key in ["Calories", "Protein", "Fat", "Carbs", "Sugar"]:
            m = re.search(rf"\*\*{key}:\*\*\s*(\d+)", macros_text)
            if m:
                entry[key.lower()] = int(m.group(1))
        if len(entry) > 1:
            macros.append(entry)

# Parse notes
notes = []
notes_match = re.search(r"### Notes\s*\n(.*?)(?=\n###|\n---|\Z)", md, re.DOTALL)
if notes_match:
    for line in notes_match.group(1).strip().split("\n"):
        line = line.strip()
        if line.startswith("- "):
            notes.append(line[2:].strip())

recipe = {
    "title": title,
    "videoId": video_id,
    "tiktok": tiktok,
    "thumbnail": thumbnail,
    "desc": desc,
    "baseType": base_type,
    "macros": macros,
    "ingredients": ingredients,
    "steps": steps,
    "notes": notes
}

# Load existing recipes.json
try:
    with open(json_path, "r") as f:
        db = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    db = []

# Find or create category
cat_found = False
for group in db:
    if group["category"] == category:
        group["recipes"].append(recipe)
        cat_found = True
        break

if not cat_found:
    db.append({"category": category, "recipes": [recipe]})

with open(json_path, "w") as f:
    json.dump(db, f, indent=2, ensure_ascii=False)

print(f"\nAdded \"{title}\" to category \"{category}\" in recipes.json")
PYEOF

echo ""
echo "Done!"
echo "  Recipe .md: $RECIPE_FILE"
[ -n "$THUMB_PATH" ] && echo "  Thumbnail:  $THUMBS_DIR/$RECIPE_NAME.jpg"
echo "  recipes.json updated"
echo ""
echo "Preview:"
echo "----------------------------------------"
cat "$RECIPE_FILE"
