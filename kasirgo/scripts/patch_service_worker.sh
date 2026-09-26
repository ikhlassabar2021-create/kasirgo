#!/bin/bash
# Patch flutter_bootstrap.js to disable service worker safely
# Run after: flutter build web

FLUTTER_BS="/workspace/kasirgo/build/web/flutter_bootstrap.js"
if [ -f "$FLUTTER_BS" ]; then
  # Only replace inside the final loader call at the bottom:
  node -e '
    const fs = require("fs");
    let content = fs.readFileSync(process.argv[1], "utf8");
    // Replace serviceWorkerSettings with empty object or null
    content = content.replace(/serviceWorkerSettings:\s*\{[\s\S]*?\}/, "serviceWorkerSettings: null");
    fs.writeFileSync(process.argv[1], content, "utf8");
  ' "$FLUTTER_BS"
  echo "Service worker disabled safely in flutter_bootstrap.js"
else
  echo "flutter_bootstrap.js not found (build first?)"
fi