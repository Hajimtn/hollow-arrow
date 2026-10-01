#!/bin/bash
# Parse-check and boot the project headless for a few frames; prints only errors/warnings.
GODOT=/Users/manhtien/Downloads/Godot.app/Contents/MacOS/Godot
cd /Users/manhtien/titan-souls
$GODOT --headless --path . --import 2>&1 | grep -E "SCRIPT ERROR|ERROR|Parse|WARNING" | head -40
echo "--- run ---"
$GODOT --headless --path . --quit-after 120 2>&1 | grep -vE "^Godot Engine|^$|OpenGL|Vulkan|Metal" | head -40
