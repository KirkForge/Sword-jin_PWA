#!/bin/bash
# Patch Godot HTML5 export with PWA service worker + manifest
# Run after Godot exports to builds/web/

set -e

BUILD_DIR="$(dirname "$0")/../builds/web"
INDEX="$BUILD_DIR/index.html"
SW="$BUILD_DIR/sw.js"
MANIFEST="$BUILD_DIR/manifest.json"

if [ ! -f "$INDEX" ]; then
    echo "ERROR: No index.html found in $BUILD_DIR"
    echo "Export from Godot first: Project → Export → HTML5 → builds/web/"
    exit 1
fi

# Inject service worker registration before </body>
if grep -q "serviceWorker" "$INDEX" 2>/dev/null; then
    echo "PWA already patched — skipping"
else
    sed -i 's|</body>|<script>\nif ("serviceWorker" in navigator) {\n  navigator.serviceWorker.register("/sw.js").then(function(r) {\n    console.log("SW registered: " + r.scope);\n  }).catch(function(e) {\n    console.warn("SW failed: " + e);\n  });\n}\n</script>\n</body>|' "$INDEX"
    echo "✅ Service worker injected"
fi

# Inject manifest link before </head>
if grep -q "manifest.json" "$INDEX" 2>/dev/null; then
    echo "Manifest already linked — skipping"
else
    sed -i 's|</head>|<link rel="manifest" href="/manifest.json">\n<meta name="theme-color" content="#c0392b">\n<meta name="mobile-web-app-capable" content="yes">\n<meta name="apple-mobile-web-app-capable" content="yes">\n<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">\n</head>|' "$INDEX"
    echo "✅ Manifest linked"
fi

echo ""
echo "PWA patch complete!"
echo "Files in $BUILD_DIR:"
ls -la "$BUILD_DIR"/*.{js,wasm,pck,html,json,sw.js} 2>/dev/null || true
echo ""
echo "To test: python3 -m http.server 8080 --directory $BUILD_DIR"
