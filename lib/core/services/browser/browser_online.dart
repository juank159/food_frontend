// Eventos `online` / `offline` del navegador — solo existen en web. En
// nativo se usa el stub (Android/Windows detectan red con
// `InternetConnectionChecker`, ver `ConnectivityService`).
export 'browser_online_stub.dart'
    if (dart.library.js_interop) 'browser_online_web.dart';
