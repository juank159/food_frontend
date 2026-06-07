import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/routes/navigation_service.dart';
import '../../../auth/data/datasources/auth_local_datasource.dart';
import '../../../auth/domain/usecases/get_current_user_usecase.dart';

/// Controlador del splash.
///
/// **Responsabilidad clave:** decidir a dónde mandar al usuario tras la
/// animación. Antes este controller siempre iba a /login después de un
/// timer fijo — eso provocaba que el usuario tuviera que loguearse cada
/// vez que abría la app, ignorando los tokens guardados.
///
/// **Flujo nuevo:**
///   1. Esperamos la animación (3.5 s) en paralelo con el auth check
///      — el chequeo es típicamente <300 ms, así que el splash sigue
///      respetando su duración mínima sin agregar latencia.
///   2. Si hay `access_token` en storage local → intentamos
///      `getCurrentUserUseCase`. Hay 2 caminos:
///      - Hit en caché local (`localDataSource.getUser`): instantáneo,
///        vamos a /home. El interceptor Dio refrescará el token al
///        primer request si está expirado.
///      - Sin caché → hace request al backend `GET /auth/me` con el
///        token. Si el backend devuelve 200, vamos a /home. Si devuelve
///        401, el interceptor Dio intenta refresh automático (ver
///        `injection_container.refreshAccessToken`); si el refresh
///        funciona, retry transparente y 200. Si todos los caminos
///        fallan → login.
///   3. Si no hay token → /login directo.
///
/// **No re-loguea innecesariamente:** el flow respeta la expiración
/// del JWT y el refresh token. Solo cae a /login cuando NO hay forma
/// de recuperar la sesión.
class SplashController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    _decideInitialRoute();
  }

  Future<void> _decideInitialRoute() async {
    // Lanzamos las dos tareas en paralelo: el delay de animación
    // (UX) y el auth check (data). Esperamos a que las DOS terminen
    // — el delay del splash sigue siendo de 3.5 s mínimo, pero no
    // pagamos esa latencia DESPUÉS para el check.
    final delayFuture = Future<void>.delayed(
      const Duration(milliseconds: 3500),
    );
    final routeFuture = _resolveRoute();

    final results = await Future.wait([delayFuture, routeFuture]);
    final route = results[1] as _InitialRoute;

    switch (route) {
      case _InitialRoute.home:
        NavigationService.toHome(clearStack: true);
        break;
      case _InitialRoute.login:
        NavigationService.toLogin();
        break;
    }
  }

  Future<_InitialRoute> _resolveRoute() async {
    final localDataSource = sl<AuthLocalDataSource>();

    final hasToken = await localDataSource.hasToken();
    if (!hasToken) return _InitialRoute.login;

    // Hay token: intentamos resolver el user. `getCurrentUser` mira
    // primero la caché local (instantáneo); si no hay, hace request
    // al backend. El interceptor Dio del proyecto refresca el token
    // automáticamente con `refresh_token` si el access expiró —
    // todo transparente acá.
    final result = await sl<GetCurrentUserUseCase>().call();
    return result.fold(
      (_) => _InitialRoute.login, // token inválido y refresh imposible
      (_) => _InitialRoute.home,
    );
  }
}

enum _InitialRoute { home, login }
