# Compila Flutter web dentro de Dokploy en cada push — ya no hace falta
# correr build_web.sh en local ni commitear build/web/.

FROM ghcr.io/cirruslabs/flutter:3.41.8 AS build
WORKDIR /app

# Copiar solo los manifests primero: si lib/ cambia pero las dependencias
# no, Docker reusa esta capa y se salta la descarga de paquetes.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter build web --release --no-wasm-dry-run --pwa-strategy=none

# Cache-busting (mismo truco que build_web.sh): fuerza a que el browser
# baje main.dart.js fresco aunque nginx lo sirva con cache "immutable".
RUN VERSION=$(date +%s) && \
    sed -i "s|\"mainJsPath\":\"main.dart.js\"|\"mainJsPath\":\"main.dart.js?v=$VERSION\"|g" build/web/flutter_bootstrap.js && \
    sed -i "s|src=\"flutter_bootstrap.js\"|src=\"flutter_bootstrap.js?v=$VERSION\"|g" build/web/index.html

FROM nginx:1.27-alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
