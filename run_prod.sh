#!/bin/bash
# Corre la app apuntando al backend de PRODUCCIÓN en Dokploy.
# Equivalente a un simple `flutter run` (porque el default ya es prod),
# pero explícito por si más adelante cambian los defaults.
#
# Uso:
#   ./run_prod.sh           → macOS
#   ./run_prod.sh -d chrome → web
#   ./run_prod.sh -d ios    → iOS simulator

cd "$(dirname "$0")"
exec flutter run \
  --dart-define=API_URL=https://food.plat.baudity.com/api/v1 \
  "$@"
