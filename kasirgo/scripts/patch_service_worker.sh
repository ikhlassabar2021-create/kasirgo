#!/bin/bash
# Patch flutter_bootstrap.js to disable service worker safely
# Run after: flutter build web

FLUTTER_BS="/workspace/kasirgo/build/web/flutter_bootstrap.js"
if [ -f "$FLUTTER_BS" ]; then
  # Match the exact invocation at the bottom of the file
  sed -i 's/serviceWorkerVersion: "[^"]*"/serviceWorkerVersion: null/g' "$FLUTTER_BS"
  sed -i 's/serviceWorkerVersion: [0-9]*/serviceWorkerVersion: null/g' "$FLUTTER_BS"
  echo "Service worker disabled in flutter_bootstrap.js"
else
  echo "flutter_bootstrap.js not found (build first?)"
fi