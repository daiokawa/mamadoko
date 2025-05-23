#!/bin/bash
cd "$(dirname "$0")"

ICON_DIR="Mamadoko/Assets.xcassets/AppIcon.appiconset"

# Create base icon with solid color
convert -size 1024x1024 xc:#2196F3 -fill "#2196F3" -draw "roundrectangle 0,0 1024,1024 100,100" "$ICON_DIR/icon-1024.png"

# Resize for other sizes
convert "$ICON_DIR/icon-1024.png" -resize 40x40 "$ICON_DIR/icon-20@2x.png"
convert "$ICON_DIR/icon-1024.png" -resize 60x60 "$ICON_DIR/icon-20@3x.png"
convert "$ICON_DIR/icon-1024.png" -resize 58x58 "$ICON_DIR/icon-29@2x.png"
convert "$ICON_DIR/icon-1024.png" -resize 87x87 "$ICON_DIR/icon-29@3x.png"
convert "$ICON_DIR/icon-1024.png" -resize 80x80 "$ICON_DIR/icon-40@2x.png"
convert "$ICON_DIR/icon-1024.png" -resize 120x120 "$ICON_DIR/icon-40@3x.png"
convert "$ICON_DIR/icon-1024.png" -resize 120x120 "$ICON_DIR/icon-60@2x.png"
convert "$ICON_DIR/icon-1024.png" -resize 180x180 "$ICON_DIR/icon-60@3x.png"

echo "Basic app icons created in $ICON_DIR"