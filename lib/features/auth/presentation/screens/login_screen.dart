import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/routes/navigation_service.dart';
import '../../../../core/utils/validators.dart';
import '../../data/datasources/auth_local_datasource.dart';
import '../controllers/auth_controller.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

/// Pantalla de login. Hero con gradient + tarjeta de formulario flotante
/// debajo. El gradient se proyecta detrás de la card para dar profundidad.
///
/// **Precarga del formulario:** al abrir, recuperamos `subdomain` y
/// `email` del último login exitoso (sin contraseña) y los ponemos en
/// los controllers. El password queda en blanco. Si el operario usa la
/// app frecuentemente con el mismo tenant + usuario, solo tipea la
/// contraseña.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthController controller = Get.find<AuthController>();

  final _formKey = GlobalKey<FormState>();
  final _tenantController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _obscurePassword = true.obs;

  /// Foco del password — lo activamos cuando precargamos tenant+email
  /// para que el operario solo tipee la contraseña, sin tocar nada más.
  final _passwordFocus = FocusNode();

  /// Cuentas que ya iniciaron sesión en este dispositivo (recientes
  /// primero), para seleccionarlas con un tap.
  final _knownAccounts =
      <({String subdomain, String email, String name})>[].obs;

  @override
  void initState() {
    super.initState();
    _loadLastLogin();
    _loadKnownAccounts();
  }

  Future<void> _loadKnownAccounts() async {
    try {
      final accounts = await sl<AuthLocalDataSource>().getKnownAccounts();
      if (!mounted) return;
      _knownAccounts.assignAll(accounts);
    } catch (_) {
      // cosmético — si falla, simplemente no mostramos atajos
    }
  }

  /// Rellena el formulario con la cuenta elegida y enfoca la contraseña.
  void _selectAccount(({String subdomain, String email, String name}) acc) {
    _tenantController.text = acc.subdomain;
    _emailController.text = acc.email;
    _passwordController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _passwordFocus.requestFocus();
    });
  }

  Future<void> _removeAccount(
      ({String subdomain, String email, String name}) acc) async {
    await sl<AuthLocalDataSource>().removeKnownAccount(
      subdomain: acc.subdomain,
      email: acc.email,
    );
    _knownAccounts.removeWhere(
      (a) => a.subdomain == acc.subdomain && a.email == acc.email,
    );
  }

  Future<void> _loadLastLogin() async {
    try {
      final last = await sl<AuthLocalDataSource>().getLastLogin();
      if (!mounted) return;
      if (last.subdomain != null && last.subdomain!.isNotEmpty) {
        _tenantController.text = last.subdomain!;
      }
      if (last.email != null && last.email!.isNotEmpty) {
        _emailController.text = last.email!;
      }
      // Si ya tenemos subdomain+email precargados, llevamos el foco
      // directo al campo de contraseña — UX óptima para usuarios
      // recurrentes (1-tap login).
      if (_tenantController.text.isNotEmpty &&
          _emailController.text.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _passwordFocus.requestFocus();
        });
      }
    } catch (_) {
      // Si no se puede leer storage, el form arranca vacío — no
      // bloqueamos la pantalla por algo cosmético.
    }
  }

  @override
  void dispose() {
    _tenantController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Breakpoints: <600 = mobile, 600-900 = tablet, >=900 = desktop.
    // Para login no queremos que el form ocupe todo el ancho en pantallas
    // grandes (queda visualmente desproporcionado y mata la jerarquía).
    // 440 px es el ancho típico de un login profesional (Stripe, Linear,
    // Notion). En mobile dejamos full-width con padding lateral.
    final isWide = screenWidth >= 600;
    final maxFormWidth = isWide ? 440.0 : double.infinity;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Gradient background — más alto en mobile (280) para cubrir
          // el hero, más bajo en wide (220) porque el contenido está
          // centrado y el gradient se vería desbalanceado si tapara
          // demasiado vertical.
          Container(
            height: isWide ? 220 : 280,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isWide ? 32 : 20,
                isWide ? 32 : 24,
                isWide ? 32 : 20,
                24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxFormWidth),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHero(),
                        const SizedBox(height: 24),
                        _buildFormCard(context),
                        const SizedBox(height: 16),
                        _buildSignUpFooter(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── Hero ───────────────────────────

  Widget _buildHero() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: const Icon(
            FontAwesomeIcons.utensils,
            size: 36,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '¡Bienvenido de nuevo!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Iniciá sesión para gestionar tu negocio',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ─────────────────────── Cuentas recientes ───────────────────────

  /// Atajos de las cuentas que ya iniciaron sesión en este dispositivo.
  /// Tap = rellena restaurante + correo y enfoca la contraseña.
  Widget _buildKnownAccounts() {
    return Obx(() {
      if (_knownAccounts.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cuentas recientes',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _knownAccounts.map(_accountChip).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Divider(color: AppColors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'o ingresá con otra cuenta',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ),
              Expanded(child: Divider(color: AppColors.border)),
            ],
          ),
          const SizedBox(height: 14),
        ],
      );
    });
  }

  Widget _accountChip(({String subdomain, String email, String name}) acc) {
    final base = acc.name.trim().isNotEmpty ? acc.name.trim() : acc.email.trim();
    final initial = base.isNotEmpty ? base[0].toUpperCase() : '?';
    return InkWell(
      onTap: () => _selectAccount(acc),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    acc.name.isNotEmpty ? acc.name : acc.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${acc.email} · ${acc.subdomain}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 15),
              color: AppColors.textHint,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
              tooltip: 'Quitar cuenta',
              onPressed: () => _removeAccount(acc),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── Form card ───────────────────────────

  Widget _buildFormCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildKnownAccounts(),
          CustomTextField(
            controller: _tenantController,
            label: 'Restaurante',
            hint: 'Subdominio (ej. demo)',
            prefixIcon: FontAwesomeIcons.shop,
            keyboardType: TextInputType.text,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresá el subdominio del restaurante';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: _emailController,
            label: 'Correo electrónico',
            hint: 'tu@correo.com',
            prefixIcon: FontAwesomeIcons.envelope,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
          ),
          const SizedBox(height: 14),
          Obx(() => CustomTextField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                label: 'Contraseña',
                hint: 'Tu contraseña',
                prefixIcon: FontAwesomeIcons.lock,
                obscureText: _obscurePassword.value,
                validator: Validators.password,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword.value
                        ? FontAwesomeIcons.eyeSlash
                        : FontAwesomeIcons.eye,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    _obscurePassword.value = !_obscurePassword.value;
                  },
                ),
              )),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: NavigationService.toForgotPassword,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: Size.zero,
              ),
              child: const Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Obx(() => CustomButton(
                text: 'Iniciar sesión',
                onPressed: () => _handleLogin(context),
                isLoading: controller.isLoading,
                icon: FontAwesomeIcons.rightToBracket,
              )),
        ],
      ),
    );
  }

  // ─────────────────────────── Sign up footer ───────────────────────────

  Widget _buildSignUpFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '¿No tenés cuenta?  ',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        TextButton(
          onPressed: NavigationService.toRegister,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(
                horizontal: 4, vertical: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: Size.zero,
          ),
          child: const Text(
            'Creá tu restaurante',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogin(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Capturamos el ScaffoldMessenger ANTES del await — después de la
    // respuesta, el context puede no estar montado (si el login fue
    // exitoso, ya navegamos a /home y este context murió). Un
    // ScaffoldMessengerState capturado antes del await sigue siendo
    // válido para hacer noop si la screen se desmontó.
    final messenger = ScaffoldMessenger.of(context);

    final error = await controller.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      tenantSubdomain: _tenantController.text.trim().toLowerCase(),
    );

    if (error == null) return; // éxito → ya navegamos a /home
    if (!context.mounted) return; // screen desmontada, nada que mostrar

    messenger.showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
