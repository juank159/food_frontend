import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import 'app_routes.dart';
import '../../core/utils/app_snackbar.dart';

/// Middleware de autenticación
///
/// Verifica si el usuario está autenticado antes de acceder a rutas protegidas.
/// Si no está autenticado, redirige al login.
class AuthGuard extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    // Intentar obtener el AuthController
    final authController = Get.find<AuthController>();

    // Si no está autenticado, redirigir a login
    if (!authController.isAuthenticated) {
      return const RouteSettings(name: AppRoutes.login);
    }

    // Si está autenticado, permitir el acceso
    return null;
  }
}

/// Middleware para rutas de solo invitados (guest)
///
/// Verifica que el usuario NO esté autenticado.
/// Si está autenticado, redirige al home.
/// Útil para login, register, etc.
class GuestGuard extends GetMiddleware {
  @override
  int? get priority => 2;

  @override
  RouteSettings? redirect(String? route) {
    // Intentar obtener el AuthController
    try {
      final authController = Get.find<AuthController>();

      // Si está autenticado, redirigir a home
      if (authController.isAuthenticated) {
        return const RouteSettings(name: AppRoutes.home);
      }
    } catch (e) {
      // Si no se puede encontrar el controller, permitir acceso
      return null;
    }

    // Si no está autenticado, permitir el acceso
    return null;
  }
}

/// Middleware para verificar roles específicos
///
/// Verifica si el usuario tiene uno de los roles requeridos para
/// acceder a la ruta. Si no, redirige al home con un mensaje de
/// "Acceso denegado". Es la última línea de defensa en el frontend —
/// el backend además bloquea con `RolesGuard` (defensa en profundidad).
class RoleGuard extends GetMiddleware {
  final List<String> requiredRoles;

  RoleGuard({required this.requiredRoles});

  @override
  int? get priority => 3;

  @override
  RouteSettings? redirect(String? route) {
    try {
      final authController = Get.find<AuthController>();

      if (!authController.isAuthenticated) {
        return const RouteSettings(name: AppRoutes.login);
      }

      final currentUser = authController.currentUser;
      if (currentUser == null) {
        return const RouteSettings(name: AppRoutes.login);
      }

      final hasRole = currentUser.hasAnyRole(requiredRoles);
      if (!hasRole) {
        // Snackbar diferido para que se muestre en la pantalla destino
        // (home) y no en la página que estaba antes de la redirección.
        Future.microtask(() {
          AppSnackbar.show(
            'Acceso denegado',
            'No tenés permisos para acceder a esta sección.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red.shade400,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        });
        return const RouteSettings(name: AppRoutes.home);
      }

      return null;
    } catch (e) {
      return const RouteSettings(name: AppRoutes.login);
    }
  }
}

/// Middleware para verificar permisos específicos
///
/// Verifica si el usuario tiene el permiso requerido para acceder a la ruta.
/// Si no tiene el permiso, redirige al home con un mensaje de error.
class PermissionGuard extends GetMiddleware {
  final List<String> requiredPermissions;

  PermissionGuard({required this.requiredPermissions});

  @override
  int? get priority => 4;

  @override
  RouteSettings? redirect(String? route) {
    try {
      final authController = Get.find<AuthController>();

      // Verificar si está autenticado primero
      if (!authController.isAuthenticated) {
        return const RouteSettings(name: AppRoutes.login);
      }

      // Verificar si tiene uno de los permisos requeridos
      final currentUser = authController.currentUser;
      if (currentUser == null) {
        return const RouteSettings(name: AppRoutes.login);
      }

      // Admin pasa siempre (el método hasAnyPermission ya lo respeta).
      // Para otros roles, exige al menos UNO de los permisos
      // requeridos. Si ninguno está habilitado, redirige a /home con
      // mensaje claro — evita pantallas vacías o errores backend.
      final hasPermission =
          currentUser.hasAnyPermission(requiredPermissions);
      if (!hasPermission) {
        AppSnackbar.show(
          'Acceso denegado',
          'Tu rol no tiene permisos para acceder a esta sección.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.shade400,
          colorText: Colors.white,
        );
        return const RouteSettings(name: AppRoutes.home);
      }

      return null;
    } catch (e) {
      return const RouteSettings(name: AppRoutes.login);
    }
  }
}

/// Middleware para verificar email verificado
///
/// Verifica si el usuario ha verificado su email.
/// Si no lo ha verificado, redirige a la pantalla de verificación.
class EmailVerifiedGuard extends GetMiddleware {
  @override
  int? get priority => 5;

  @override
  RouteSettings? redirect(String? route) {
    try {
      final authController = Get.find<AuthController>();

      // Verificar si está autenticado primero
      if (!authController.isAuthenticated) {
        return const RouteSettings(name: AppRoutes.login);
      }

      final currentUser = authController.currentUser;
      if (currentUser == null) {
        return const RouteSettings(name: AppRoutes.login);
      }

      // TODO: Verificar email cuando la propiedad esté disponible en User entity
      // if (!currentUser.emailVerified) {
      //   return const RouteSettings(name: AppRoutes.verifyEmail);
      // }

      return null;
    } catch (e) {
      return const RouteSettings(name: AppRoutes.login);
    }
  }
}

/// Middleware para logging de navegación
///
/// Registra todas las navegaciones para debugging y analytics
class NavigationLoggerMiddleware extends GetMiddleware {
  @override
  int? get priority => 0;

  @override
  RouteSettings? redirect(String? route) {
    if (route != null) {
      debugPrint('🧭 Navegando a: $route');
    }
    return null;
  }

  @override
  GetPage? onPageCalled(GetPage? page) {
    if (page != null) {
      debugPrint('📄 Página llamada: ${page.name}');
    }
    return super.onPageCalled(page);
  }
}
