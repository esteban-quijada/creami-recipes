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

URL="$1"
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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RECIPES_DIR="$SCRIPT_DIR/recipes"
THUMBS_DIR="$SCRIPT_DIR/thumbnails"
mkdir -p "$RECIPES_DIR" "$THUMBS_DIR"

# Download thumbnail
echo "Downloading thumbnail..."
yt-dlp --write-thumbnail --skip-download --convert-thumbnails jpg \
    -o "$THUMBS_DIR/$RECIPE_NAME" "$URL" 2>/dev/null || true

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
echo "$CONTENT" | fabric --pattern extract_creami_recipe > "$RECIPE_FILE"

# Build metadata header
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

    THUMB=$(find "$THUMBS_DIR" -name "$RECIPE_NAME.*" -type f | head -1)
    [ -n "$THUMB" ] && echo "thumbnail: ${THUMB#$SCRIPT_DIR/}"

    echo "---"
} >> "$RECIPE_FILE"

echo ""
echo "Done!"
echo "  Recipe:    $RECIPE_FILE"
THUMB=$(find "$THUMBS_DIR" -name "$RECIPE_NAME.*" -type f | head -1)
[ -n "$THUMB" ] && echo "  Thumbnail: $THUMB"
echo ""
echo "Preview:"
echo "----------------------------------------"
cat "$RECIPE_FILE"
