import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool browserIsOnline() => web.window.navigator.onLine;

Stream<bool> browserOnlineChanges() {
  late final StreamController<bool> controller;
  final onOnline = ((web.Event _) => controller.add(true)).toJS;
  final onOffline = ((web.Event _) => controller.add(false)).toJS;
  controller = StreamController<bool>.broadcast(
    onListen: () {
      web.window.addEventListener('online', onOnline);
      web.window.addEventListener('offline', onOffline);
    },
    onCancel: () {
      web.window.removeEventListener('online', onOnline);
      web.window.removeEventListener('offline', onOffline);
    },
  );
  return controller.stream;
}
