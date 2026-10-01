#!/bin/bash
# Serves the exported build at http://localhost:8060  (browsers refuse to run it from file://)
cd "$(dirname "$0")/../build/web" && echo "Open http://localhost:8060" && python3 -m http.server 8060
