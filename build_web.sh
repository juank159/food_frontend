#!/bin/bash
set -e

echo "🔨 Compilando Flutter web..."
flutter build web --release --no-wasm-dry-run --pwa-strategy=none

VERSION=$(date +%s)
echo "📦 Versión: $VERSION"

# Parchear flutter_bootstrap.js para que cargue main.dart.js con versión
# Flutter pone "mainJsPath":"main.dart.js" en el buildConfig — cambiar esa URL
# hace que el browser descargue el archivo fresco aunque lo tenga en caché con "immutable"
sed -i '' "s|\"mainJsPath\":\"main.dart.js\"|\"mainJsPath\":\"main.dart.js?v=$VERSION\"|g" build/web/flutter_bootstrap.js

# Parchear index.html para que cargue flutter_bootstrap.js con versión
sed -i '' "s|src=\"flutter_bootstrap.js\"|src=\"flutter_bootstrap.js?v=$VERSION\"|g" build/web/index.html

echo "✅ Build listo con cache-busting v=$VERSION"
echo ""
echo "Ahora ejecuta:"
echo "  git add -f build/web/ && git add . && git commit -m 'deploy web v$VERSION' && git push"
