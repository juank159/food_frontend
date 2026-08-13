# ── Stage 1: Build Flutter Web ────────────────────────────────────────────────
FROM debian:bookworm-slim AS builder

ARG FLUTTER_VERSION=3.41.8

# Dependencias del sistema
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git unzip xz-utils zip ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Instalar Flutter SDK
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} \
    https://github.com/flutter/flutter.git /opt/flutter

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Pre-cache solo web (evita descargar sdk completo de android/ios)
RUN flutter config --enable-web && flutter precache --web

WORKDIR /app

# Copiar primero pubspec para aprovechar cache de Docker layers
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copiar el resto del código
COPY . .

# Build web en modo release
RUN flutter build web --release --no-wasm-dry-run

# ── Stage 2: Servir con nginx ─────────────────────────────────────────────────
FROM nginx:1.27-alpine

# Copiar la build de Flutter
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copiar configuración de nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
