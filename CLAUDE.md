# frontend (menu_plat) — notas para Claude

App Flutter del POS: admin, meseros, cocina, impresión térmica. Ver también `../CLAUDE.md` para el mapa general de los 3 repos.

## Impresión térmica — HAY DOS CAMINOS TOTALMENTE DISTINTOS

Esto es lo más fácil de romper sin darse cuenta porque son dos implementaciones separadas del mismo ticket. Antes de tocar cualquier cosa de impresión, identificar cuál camino aplica:

**`connection_type: "system"`** (impresora del SO — CUPS/Windows/AirPrint):
- El dispositivo pide el PDF ya armado al **backend**: `GET /orders/:id/receipt-pdf` (o similar) → `thermal-print.service.ts` (NestJS + PDFKit).
- El backend hace `loadOrderForPrint()` con los `relations` de TypeORM — si un dato nuevo (ej. un extra) no sale en el ticket, revisar primero que la relation esté en ese array.
- El SO se encarga de rasterizar el PDF.
- Funciona en Flutter Web (el navegador abre el diálogo de impresión).

**`connection_type: "network"`** (impresora TCP directa, puerto 9100 — Epson TM, Xprinter, Bixolon, etc.):
- El dispositivo pide el **JSON crudo** de la orden (`GET /orders/:id`) y arma el ticket ESC/POS **localmente**, en Dart, en `lib/features/printer_configs/data/esc_pos_generator.dart`.
- `lib/features/printer_configs/data/printing_orchestrator.dart` (`_toTicketItem`) es donde se mapea el `OrderModel`/`OrderItemModel` de la API al `TicketItem` que consume el generador. **Cualquier campo nuevo que quieras imprimir en una red printer hay que agregarlo ahí, no en el backend.**
- El envío es un socket TCP crudo abierto **desde el propio dispositivo** (`lib/features/printer_configs/data/printer_dispatcher.dart`, `Socket.connect(host, port)` de `dart:io`) directo a la IP:puerto de la impresora (ej. `192.168.110.186:9100`). El backend nunca se entera de esto.
- **El backend NO participa en generar el ticket** — solo sirvió el JSON de la orden.
- El dispositivo que imprime tiene que estar en la **misma red LAN** que la impresora.
- **NO funciona en Flutter Web** — `dart:io Socket` no existe en navegador (ver `lib/core/stubs/io_stub.dart`, que lanza `UnsupportedError` a propósito). Esto solo puede correr desde una build **nativa** (Windows/Android/macOS/Linux) instalada en el dispositivo POS.

> Bug real que ya pasó por esto (2026-09): un extra/modificador no salía en el ticket de una impresora `network` porque `_toTicketItem` leía `m.modifierName` (campo plano `modifier_name`, que el backend nunca manda) en vez de `m.modifier?.name` (el objeto anidado que sí llega). El nombre salía `null`, se filtraba en silencio, y el ticket quedaba sin el extra — sin ningún error visible. Arreglar algo similar en el backend (PDFKit) NO tuvo ningún efecto porque esa impresora usa el otro camino.

## Auto-deploy vs. build nativa — no asumir que un push ya lo arregló

`Dockerfile` en esta carpeta compila **Flutter Web** vía Dokploy en cada push a `main` — eso se actualiza solo.

Si el dispositivo del POS corre una **build nativa instalada** (no el navegador), un `git push` **no la actualiza**. Hay que:
1. Confirmar con el usuario qué build corre el dispositivo (Windows/Android/macOS/Linux) — no asumir.
2. Recompilar esa build (`flutter build windows|apk|macos|linux`) y reinstalarla/redistribuirla a mano.

Esto importa sobre todo para cambios en el camino `network` de impresión (arriba), que es nativo por definición.

## Modelos de orden

`OrderItemModifierModel` (`lib/features/orders/data/models/order_item_modifier_model.dart`) tiene un campo `modifierName` (de la key JSON `modifier_name`) que el backend **nunca envía** — es vestigial. El nombre real viaja anidado en `modifier: { name, ... }`. Usar siempre `m.modifier?.name`, con `m.modifierName` solo como fallback.
