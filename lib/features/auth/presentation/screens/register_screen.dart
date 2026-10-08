import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/validators.dart';
import '../controllers/auth_controller.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/password_strength_checklist.dart';

/// Tipos de negocio soportados — mismos valores que el enum `BusinessType`
/// del backend (`common/constants/enums.ts`). No existe un enum Dart
/// equivalente porque este es el único lugar del frontend que lo usa.
const _businessTypes = <({String value, String label})>[
  (value: 'restaurant', label: 'Restaurante'),
  (value: 'fast_food', label: 'Comida rápida'),
  (value: 'ice_cream', label: 'Heladería'),
  (value: 'pizzeria', label: 'Pizzería'),
  (value: 'bakery', label: 'Panadería'),
];

/// Pantalla de alta de un negocio NUEVO ("Crear mi restaurante"):
/// crea el tenant + el usuario dueño/admin en un solo paso
/// (`POST /auth/signup`) y arranca sesión directo.
///
/// **Por qué esta pantalla reemplazó al registro "unirse a un tenant
/// existente"**: esa otra pantalla (ahora retirada de acá) le pedía al
/// usuario el subdominio de un negocio YA creado — pero no hay ninguna
/// forma pública de crear ese negocio primero, así que cualquiera que
/// tocara "Creá tu restaurante" desde el login recibía "Tenant not
/// found" sin importar qué escribiera. Esta pantalla es la que
/// realmente crea el negocio.
class RegisterScreen extends GetView<AuthController> {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final businessNameController = TextEditingController();
    final subdomainController = TextEditingController();
    final fullNameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final selectedBusinessType = ValueNotifier<String>(_businessTypes.first.value);

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
                          businessNameController: businessNameController,
                          subdomainController: subdomainController,
                          selectedBusinessType: selectedBusinessType,
                          fullNameController: fullNameController,
                          emailController: emailController,
                          phoneController: phoneController,
                          passwordController: passwordController,
                          confirmPasswordController: confirmPasswordController,
                          onSubmit: () => _handleSignUp(
                            context,
                            formKey,
                            businessNameController,
                            subdomainController,
                            selectedBusinessType,
                            fullNameController,
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
            Icons.storefront_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Crear mi restaurante',
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
          'Dale de alta a tu negocio y empezá tu prueba gratis de 30 días',
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
    required TextEditingController businessNameController,
    required TextEditingController subdomainController,
    required ValueNotifier<String> selectedBusinessType,
    required TextEditingController fullNameController,
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
          const _SectionLabel('Tu negocio'),
          const SizedBox(height: 10),
          CustomTextField(
            controller: businessNameController,
            label: 'Nombre del negocio',
            hint: 'Ej. Pizzería Don Luigi',
            prefixIcon: Icons.storefront_outlined,
            validator: (value) =>
                Validators.name(value, fieldName: 'El nombre del negocio'),
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          _BusinessTypeDropdown(selected: selectedBusinessType),
          const SizedBox(height: 14),
          CustomTextField(
            controller: subdomainController,
            label: 'Subdominio',
            hint: 'ej. donluigi (sin espacios)',
            prefixIcon: Icons.link,
            validator: Validators.subdomain,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.text,
            onChanged: (value) {
              final sanitized = value.toLowerCase();
              if (sanitized != value) {
                subdomainController.value = subdomainController.value.copyWith(
                  text: sanitized,
                  selection: TextSelection.collapsed(offset: sanitized.length),
                );
              }
            },
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Tus datos (dueño/admin)'),
          const SizedBox(height: 10),
          CustomTextField(
            controller: fullNameController,
            label: 'Nombre completo',
            hint: 'Tu nombre y apellido',
            prefixIcon: Icons.person_outline,
            validator: Validators.name,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
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
                validator: (value) =>
                    Validators.confirmPassword(value, passwordController.text),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => onSubmit(),
              )),
          const SizedBox(height: 10),
          PasswordStrengthChecklist(
            passwordController: passwordController,
            confirmController: confirmPasswordController,
          ),
          const SizedBox(height: 16),
          const _TermsCopy(),
          const SizedBox(height: 16),
          Obx(() => CustomButton(
                text: 'Crear mi restaurante',
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

  Future<void> _handleSignUp(
    BuildContext context,
    GlobalKey<FormState> formKey,
    TextEditingController businessNameController,
    TextEditingController subdomainController,
    ValueNotifier<String> selectedBusinessType,
    TextEditingController fullNameController,
    TextEditingController emailController,
    TextEditingController phoneController,
    TextEditingController passwordController,
  ) async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    final error = await controller.signUp(
      businessName: businessNameController.text.trim(),
      businessType: selectedBusinessType.value,
      subdomain: subdomainController.text.trim().toLowerCase(),
      fullName: fullNameController.text.trim(),
      email: emailController.text.trim(),
      phoneNumber: phoneController.text.trim().isEmpty
          ? null
          : phoneController.text.trim(),
      password: passwordController.text,
    );

    if (error == null) return; // éxito → ya navegamos a /home
    if (!context.mounted) return;

    AppSnackbar.show(
      'Error',
      error,
      context: context,
      backgroundColor: Colors.red.shade400,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppColors.textSecondary,
        letterSpacing: 0.2,
      ),
    );
  }
}

/// Selector de tipo de negocio — mismo look que `CustomTextField`
/// (borde + label flotante) para que no desentone en el form.
class _BusinessTypeDropdown extends StatelessWidget {
  final ValueNotifier<String> selected;
  const _BusinessTypeDropdown({required this.selected});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: selected,
      builder: (context, value, _) {
        return DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            labelText: 'Tipo de negocio',
            prefixIcon: const Icon(Icons.category_outlined,
                color: AppColors.primary, size: 22),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          items: [
            for (final type in _businessTypes)
              DropdownMenuItem(value: type.value, child: Text(type.label)),
          ],
          onChanged: (value) {
            if (value != null) selected.value = value;
          },
        );
      },
    );
  }
}

class _TermsCopy extends StatelessWidget {
  const _TermsCopy();

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        text: 'Al crear tu restaurante aceptás nuestros ',
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
