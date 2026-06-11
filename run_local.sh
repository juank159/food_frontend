#!/bin/bash
# Corre la app contra el BACKEND LOCAL (npm run start:dev en otra terminal).
#
# Requisitos:
#   - Tener el backend corriendo: cd ../backend && npm run start:dev
#   - Haber aplicado las migraciones: cd ../backend && npm run migration:run
#
# Si estás en Android emulator, `localhost` desde la app NO es tu Mac
# (es el emulator) — usá `10.0.2.2` (alias del host desde el emulator).
#
# Uso:
#   ./run_local.sh           → macOS (localhost OK)
#   ./run_local.sh -d chrome → web (localhost OK)
#   ./run_local.sh -d ios    → iOS sim (localhost OK)

cd "$(dirname "$0")"

# Detectar si el device es Android emulator para usar 10.0.2.2.
# Si pasás -d <android-device-id>, ajustá manualmente la URL.
URL="http://localhost:3000/api/v1"
for arg in "$@"; do
  if [[ "$arg" == *"emulator"* || "$arg" == *"android"* ]]; then
    URL="http://10.0.2.2:3000/api/v1"
    break
  fi
done

echo "→ Backend URL: $URL"
exec flutter run \
  --dart-define=API_URL="$URL" \
  "$@"
