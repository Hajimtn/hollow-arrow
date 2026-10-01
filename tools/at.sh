#!/bin/bash
# usage: tools/at.sh <scenario> [windowed]   -> runs an autotest scenario
GODOT=/Users/manhtien/Downloads/Godot.app/Contents/MacOS/Godot
SP=$(cat /tmp/claude-501/sp.txt)
cd /Users/manhtien/titan-souls
if [ "$2" == "windowed" ]; then
  $GODOT --path . --fixed-fps 60 --resolution 960x540 -- --autotest=$1 --shots=$SP/shots 2>&1 | grep -vE "^Godot Engine|^$|OpenGL|Metal|Apple|ALSA" | head -${3:-80}
else
  $GODOT --headless --path . --fixed-fps 60 -- --autotest=$1 2>&1 | grep -vE "^Godot Engine|^$" | head -${3:-80}
fi
