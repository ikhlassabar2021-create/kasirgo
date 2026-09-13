#!/bin/bash
# Patch flutter_bootstrap.js to disable service worker (prevents stale cache)
# Run after: flutter build web

FLUTTER_BS="/workspace/kasirgo/build/web/flutter_bootstrap.js"
if [ -f "$FLUTTER_BS" ]; then
  sed -i 's/serviceWorkerVersion:[^,}]*/serviceWorkerVersion: null/' "$FLUTTER_BS"
  echo "Service worker disabled in flutter_bootstrap.js"
else
  echo "flutter_bootstrap.js not found (build first?)"
fi