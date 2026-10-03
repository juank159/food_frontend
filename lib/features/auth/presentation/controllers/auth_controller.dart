//lib/features/auth/presentation/controllers/auth_controller.dart
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/routes/navigation_service.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../orders/presentation/controllers/pending_review_watcher.dart';
import '../../../subscriptions/presentation/controllers/trial_expiry_reminder_service.dart';
import '../../data/datasources/auth_local_datasource.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/sign_up_business_usecase.dart';
import '../../domain/usecases/update_profile_usecase.dart';

/// Auth Controller using GetX
/// Manages authentication state and business logic
class AuthController extends GetxController {
  final LoginUseCase loginUseCase;
  final RegisterUseCase registerUseCase;
  final SignUpBusinessUseCase signUpBusinessUseCase;
  final LogoutUseCase logoutUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final UpdateProfileUseCase updateProfileUseCase;

  AuthController({
    required this.loginUseCase,
    required this.registerUseCase,
    required this.signUpBusinessUseCase,
    required this.logoutUseCase,
    required this.getCurrentUserUseCase,
    required this.updateProfileUseCase,
  });

  // Observable state
  final _isLoading = false.obs;
  final Rx<User?> _currentUser = Rx<User?>(null);
  final _isAuthenticated = false.obs;

  // Mostrar/ocultar contraseña en el registro (ojito).
  final RxBool obscureRegisterPassword = true.obs;
  final RxBool obscureRegisterConfirm = true.obs;
  void toggleRegisterPassword() =>
      obscureRegisterPassword.value = !obscureRegisterPassword.value;
  void toggleRegisterConfirm() =>
      obscureRegisterConfirm.value = !obscureRegisterConfirm.value;

  // Getters
  bool get isLoading => _isLoading.value;
  User? get currentUser => _currentUser.value;

  /// Versión reactiva — útil dentro de `Obx()` cuando la UI debe
  /// refrescarse al cambiar el usuario (login, logout, role refresh).
  /// Usar este getter en `Obx()` y no `currentUser` directo.
  User? get currentUserRx => _currentUser.value;
  bool get isAuthenticated => _isAuthenticated.value;

  @override
  void onInit() {
    super.onInit();
    checkAuthStatus();
  }

  /// Check if user is authenticated on app start
  Future<void> checkAuthStatus() async {
    _isLoading.value = true;

    final result = await getCurrentUserUseCase();

    result.fold(
      (failure) {
        _isAuthenticated.value = false;
        _currentUser.value = null;
      },
      (user) {
        _isAuthenticated.value = true;
        _currentUser.value = user;
        _startBackgroundServices(user);
      },
    );

    _isLoading.value = false;
  }

  /// Arranca los servicios singleton que dependen del user logueado:
  ///   - `PendingReviewWatcher`: polea pedidos por QR pendientes y
  ///     avisa al mesero con haptic + sonido + snackbar. Solo roles
  ///     que pueden aprobar.
  ///   - `TrialExpiryReminderService`: recuerda cada 2h que el trial
  ///     está por vencer (1 día o menos). Solo admin.
  void _startBackgroundServices(User user) {
    try {
      Get.find<PendingReviewWatcher>().startForRole(user.roleCode);
    } catch (_) {
      // El servicio aún no está disponible — pasa en el primer boot
      // si checkAuthStatus corre antes de Get.putAsync. Reintentamos
      // perezosamente.
    }
    try {
      Get.find<TrialExpiryReminderService>().startForUser(user);
    } catch (_) {}
  }

  /// Login user against the given tenant subdomain.
  ///
  /// Retorna `null` si el login fue exitoso (la screen ya está en
  /// `/home`). Si falló, retorna el mensaje de error como `String`
  /// para que la screen lo muestre con `AppSnackbar` — NO se muestra
  /// desde acá porque `Get.snackbar` depende del Overlay del route
  /// activo y crashea cuando hay navegación en curso (cola async
  /// fire-and-forget de GetX, fuera de cualquier try/catch).
  Future<String?> login({
    required String email,
    required String password,
    required String tenantSubdomain,
  }) async {
    _isLoading.value = true;

    final result = await loginUseCase(
      email: email,
      password: password,
      tenantSubdomain: tenantSubdomain,
    );

    return result.fold<String?>(
      (failure) {
        _isLoading.value = false;
        return failure.message;
      },
      (authResponse) {
        _isLoading.value = false;
        _isAuthenticated.value = true;
        _currentUser.value = authResponse.user;
        _startBackgroundServices(authResponse.user);
        // Guardamos los datos del login (subdomain + email, SIN
        // contraseña) para precargar el formulario la próxima vez
        // que el usuario abra la app o cierre sesión. Fire-and-
        // forget: si falla no bloquea el flujo.
        sl<AuthLocalDataSource>().cacheLastLogin(
          subdomain: tenantSubdomain,
          email: email,
        );
        // Recordar la cuenta (con nombre) en la lista de cuentas conocidas
        // del dispositivo, para seleccionarla rápido en próximos logins.
        final u = authResponse.user;
        final displayName = '${u.firstName} ${u.lastName}'.trim();
        sl<AuthLocalDataSource>().cacheKnownAccount(
          subdomain: tenantSubdomain,
          email: email,
          name: displayName.isEmpty ? email : displayName,
        );
        // Registrar token FCM para push notifications (fire-and-forget).
        PushNotificationService.registerToken(sl<Dio>()).ignore();
        NavigationService.toHome(clearStack: true);
        return null;
      },
    );
  }

  /// Register new user inside the given tenant subdomain.
  /// Mismo contrato que [login]: `null` = OK, `String` = mensaje de error.
  Future<String?> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phoneNumber,
    required String tenantSubdomain,
  }) async {
    _isLoading.value = true;

    final result = await registerUseCase(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      tenantSubdomain: tenantSubdomain,
    );

    return result.fold<String?>(
      (failure) {
        _isLoading.value = false;
        return failure.message;
      },
      (authResponse) {
        _isLoading.value = false;
        _isAuthenticated.value = true;
        _currentUser.value = authResponse.user;
        _startBackgroundServices(authResponse.user);
        NavigationService.toHome(clearStack: true);
        return null;
      },
    );
  }

  /// Alta de un negocio NUEVO (tenant + dueño) en un solo paso —
  /// pantalla "Crear mi restaurante". Distinto de [register]: no hace
  /// falta `tenantSubdomain` porque todavía no existe ningún tenant.
  Future<String?> signUp({
    required String businessName,
    required String businessType,
    required String subdomain,
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    _isLoading.value = true;

    final result = await signUpBusinessUseCase(
      businessName: businessName,
      businessType: businessType,
      subdomain: subdomain,
      email: email,
      password: password,
      fullName: fullName,
      phoneNumber: phoneNumber,
    );

    return result.fold<String?>(
      (failure) {
        _isLoading.value = false;
        return failure.message;
      },
      (authResponse) {
        _isLoading.value = false;
        _isAuthenticated.value = true;
        _currentUser.value = authResponse.user;
        _startBackgroundServices(authResponse.user);
        NavigationService.toHome(clearStack: true);
        return null;
      },
    );
  }

  /// Logout user
  Future<void> logout() async {
    _isLoading.value = true;

    final result = await logoutUseCase();

    result.fold(
      (failure) {
        _isLoading.value = false;
        // Even if logout fails on server, clear local state
        _clearAuthState();
        NavigationService.toLogin();
      },
      (_) {
        _isLoading.value = false;
        _clearAuthState();

        // Sin snackbar post-navegación (mismo motivo que en `login`):
        // la cola async de `Get.snackbar` puede ejecutarse cuando
        // /home/* ya se desmontó pero /login aún no terminó de
        // construir su Overlay → crash. La transición a /login es
        // feedback suficiente de que cerraste sesión.
        NavigationService.toLogin();
      },
    );
  }

  /// Actualiza nombre/apellido/teléfono del usuario autenticado contra
  /// `PATCH /users/me`. Devuelve `null` en éxito (y refresca
  /// [currentUser] al toque, sin re-login) o un mensaje de error
  /// legible para mostrar en un snackbar.
  Future<String?> updateProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
  }) async {
    final result = await updateProfileUseCase(
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
    );
    return result.fold(
      (failure) => failure.message,
      (user) {
        _currentUser.value = user;
        return null;
      },
    );
  }

  /// Clear authentication state
  void _clearAuthState() {
    _isAuthenticated.value = false;
    _currentUser.value = null;
    // Desregistrar token FCM antes de limpiar el estado (fire-and-forget).
    PushNotificationService.unregisterToken(sl<Dio>()).ignore();
    // Detener los servicios globales cuando el usuario cierra sesión —
    // sin esto seguirían poleando sin auth válida y generando 401.
    try {
      Get.find<PendingReviewWatcher>().stop();
    } catch (_) {}
    try {
      Get.find<TrialExpiryReminderService>().stop();
    } catch (_) {}
  }
}
