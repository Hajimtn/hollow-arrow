#!/bin/bash
# Exports the Web build to build/web (needs the Web export templates for this Godot version) and zips it for itch.io etc.
cd "$(dirname "$0")/.."
GODOT=${GODOT:-/Users/manhtien/Downloads/Godot.app/Contents/MacOS/Godot}
mkdir -p build/web && "$GODOT" --headless --path . --export-release Web build/web/index.html
(cd build/web && rm -f ../hollow-arrow-web.zip && zip -qr ../hollow-arrow-web.zip .)
echo "built: build/web/index.html and build/hollow-arrow-web.zip"
