import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/config/theme/app_theme.dart';
import 'core/di/injection_container.dart' as di;
import 'core/routes/app_pages.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/sync_handlers.dart';
import 'features/orders/presentation/controllers/pending_review_watcher.dart';
import 'features/settings/presentation/controllers/payment_listener_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar datos de locale para DateFormat en español (DateFormat('...', 'es')).
  await initializeDateFormatting('es', null);

  // Inicializar Hive (base de datos local para modo offline)
  await Hive.initFlutter();

  // FCM — inicializa Firebase y crea el canal de notificaciones Android.
  // Si google-services.json / GoogleService-Info.plist no están presentes,
  // cae silenciosamente y el sistema de polling sigue activo.
  await PushNotificationService.init();

  // Initialize dependency injection
  await di.init();

  // Register sync handlers (orders + payments) so processQueue() knows
  // how to replay queued operations when internet reconnects.
  SyncHandlers.register();

  // Servicio singleton de notificación de pedidos por QR — vivo
  // durante toda la sesión. `permanent: true` evita que GetX lo
  // destruya al cambiar de ruta. El AuthController lo arranca
  // (`startForRole`) según el rol del user logueado.
  Get.put(PendingReviewWatcher(), permanent: true);

  // Escucha de pagos bancarios: se inicializa al arrancar para que el
  // servicio nativo (NotificationListenerService) reciba la config guardada
  // (bancos habilitados, template) aunque el usuario nunca abra la pantalla.
  Get.put(PaymentListenerController(), permanent: true);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MenuPlatApp());
}

class MenuPlatApp extends StatelessWidget {
  const MenuPlatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Menu Plat',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.lightTheme,

      // Initial Route
      initialRoute: AppPages.initial,

      // Routes - Ahora usando el sistema profesional de rutas
      getPages: AppPages.pages,

      // Default transition
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),

      // Route not found — usa AppNotFoundScreen del design system.
      unknownRoute: AppPages.unknownRoute,

      // Enable log
      enableLog: true,
    );
  }
}
