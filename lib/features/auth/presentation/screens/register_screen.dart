import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../controllers/auth_controller.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

/// Pantalla de registro. Mismo lenguaje visual que login: hero gradient
/// + tarjeta de formulario con sombra. El form es más largo así que el
/// hero se mantiene compacto para no robar espacio en mobile.
class RegisterScreen extends GetView<AuthController> {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final tenantController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    // Mismo patrón responsive que login_screen: limitar el ancho del
    // form en pantallas grandes para que no se vea desproporcionado.
    // Register necesita un poco más de ancho (más campos) — 500 px en
    // vez de 440 del login.
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 600;
    final maxFormWidth = isWide ? 500.0 : double.infinity;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Container(
            height: 220,
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
                isWide ? 24 : 16,
                isWide ? 32 : 20,
                24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxFormWidth),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeroBar(context),
                        const SizedBox(height: 16),
                        _buildHeroContent(),
                        const SizedBox(height: 20),
                        _buildFormCard(
                          tenantController: tenantController,
                          firstNameController: firstNameController,
                          lastNameController: lastNameController,
                          emailController: emailController,
                          phoneController: phoneController,
                          passwordController: passwordController,
                          confirmPasswordController: confirmPasswordController,
                          onSubmit: () => _handleRegister(
                            context,
                            formKey,
                            tenantController,
                            firstNameController,
                            lastNameController,
                            emailController,
                            phoneController,
                            passwordController,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildLoginFooter(context),
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

  Widget _buildHeroBar(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroContent() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.restaurant_menu_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Crear cuenta',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Completá tus datos para comenzar',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────── Form ───────────────────────────

  Widget _buildFormCard({
    required TextEditingController tenantController,
    required TextEditingController firstNameController,
    required TextEditingController lastNameController,
    required TextEditingController emailController,
    required TextEditingController phoneController,
    required TextEditingController passwordController,
    required TextEditingController confirmPasswordController,
    required VoidCallback onSubmit,
  }) {
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
          CustomTextField(
            controller: tenantController,
            label: 'Restaurante',
            hint: 'Subdominio (ej. demo)',
            prefixIcon: Icons.storefront_outlined,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresá el subdominio del restaurante';
              }
              return null;
            },
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: firstNameController,
                  label: 'Nombre',
                  hint: 'Tu nombre',
                  prefixIcon: Icons.person_outline,
                  validator: Validators.name,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomTextField(
                  controller: lastNameController,
                  label: 'Apellido',
                  hint: 'Tu apellido',
                  prefixIcon: Icons.person_outline,
                  validator: Validators.name,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: emailController,
            label: 'Correo electrónico',
            hint: 'tu@correo.com',
            prefixIcon: Icons.email_outlined,
            validator: Validators.email,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: phoneController,
            label: 'Teléfono (opcional)',
            hint: '+573001234567',
            prefixIcon: Icons.phone_outlined,
            validator: (value) {
              if (value == null || value.isEmpty) return null;
              return Validators.phone(value);
            },
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          Obx(() => CustomTextField(
                controller: passwordController,
                label: 'Contraseña',
                hint: '8+ caracteres, mayús, número, especial',
                prefixIcon: Icons.lock_outline,
                obscureText: controller.obscureRegisterPassword.value,
                validator: Validators.password,
                textInputAction: TextInputAction.next,
                suffixIcon: IconButton(
                  icon: Icon(
                    controller.obscureRegisterPassword.value
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: controller.obscureRegisterPassword.value
                      ? 'Mostrar contraseña'
                      : 'Ocultar contraseña',
                  onPressed: controller.toggleRegisterPassword,
                ),
              )),
          const SizedBox(height: 14),
          Obx(() => CustomTextField(
                controller: confirmPasswordController,
                label: 'Confirmar contraseña',
                hint: 'Repetí la contraseña',
                prefixIcon: Icons.lock_outline,
                obscureText: controller.obscureRegisterConfirm.value,
                suffixIcon: IconButton(
                  icon: Icon(
                    controller.obscureRegisterConfirm.value
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: controller.obscureRegisterConfirm.value
                      ? 'Mostrar contraseña'
                      : 'Ocultar contraseña',
                  onPressed: controller.toggleRegisterConfirm,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Confirmá tu contraseña';
                  }
                  if (value != passwordController.text) {
                    return 'Las contraseñas no coinciden';
                  }
                  return null;
                },
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => onSubmit(),
              )),
          const SizedBox(height: 16),
          // Términos
          const _TermsCopy(),
          const SizedBox(height: 16),
          Obx(() => CustomButton(
                text: 'Crear cuenta',
                onPressed: controller.isLoading ? null : onSubmit,
                isLoading: controller.isLoading,
              )),
        ],
      ),
    );
  }

  Widget _buildLoginFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '¿Ya tenés cuenta?  ',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: Size.zero,
          ),
          child: const Text(
            'Iniciar sesión',
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

  Future<void> _handleRegister(
    BuildContext context,
    GlobalKey<FormState> formKey,
    TextEditingController tenantController,
    TextEditingController firstNameController,
    TextEditingController lastNameController,
    TextEditingController emailController,
    TextEditingController phoneController,
    TextEditingController passwordController,
  ) async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    // Capturamos el messenger antes del await — si el register fue
    // exitoso, este context ya está muerto cuando vuelva. Mismo
    // patrón que `LoginScreen._handleLogin`.
    final messenger = ScaffoldMessenger.of(context);

    final error = await controller.register(
      firstName: firstNameController.text.trim(),
      lastName: lastNameController.text.trim(),
      email: emailController.text.trim(),
      phoneNumber: phoneController.text.trim().isEmpty
          ? null
          : phoneController.text.trim(),
      password: passwordController.text,
      tenantSubdomain: tenantController.text.trim().toLowerCase(),
    );

    if (error == null) return; // éxito → ya navegamos a /home
    if (!context.mounted) return;

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

class _TermsCopy extends StatelessWidget {
  const _TermsCopy();

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        text: 'Al registrarte aceptás nuestros ',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
        children: [
          TextSpan(
            text: 'Términos',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: ' y '),
          TextSpan(
            text: 'Política de Privacidad',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
