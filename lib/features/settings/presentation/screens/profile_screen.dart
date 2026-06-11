import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../../core/utils/app_snackbar.dart';

/// Perfil del usuario. Muestra avatar grande con iniciales, nombre y
/// formulario para editar datos personales. Por ahora "guardar"
/// muestra un Snackbar — la integración con `PATCH /users/:id` es
/// trabajo de otro agente.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    final user = Get.find<AuthController>().currentUser;
    _firstNameController = TextEditingController(text: user?.firstName ?? '');
    _lastNameController = TextEditingController(text: user?.lastName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Get.find<AuthController>().currentUser;
    final initials = user != null
        ? '${user.firstName.isNotEmpty ? user.firstName[0] : ''}'
                '${user.lastName.isNotEmpty ? user.lastName[0] : ''}'
            .toUpperCase()
        : 'U';
    final fullName = user?.fullName ?? 'Usuario';
    final roleName = user?.roleName ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(initials: initials, name: fullName, role: roleName),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    AppFormSection(
                      title: 'Información personal',
                      subtitle: 'Datos visibles dentro de la plataforma',
                      icon: Icons.person_outline,
                      children: [
                        TextFormField(
                          controller: _firstNameController,
                          decoration: appInputDecoration(
                            label: 'Nombre',
                            hint: 'Tu nombre',
                            prefixIcon: Icons.person_outline,
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'El nombre es requerido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _lastNameController,
                          decoration: appInputDecoration(
                            label: 'Apellido',
                            hint: 'Tu apellido',
                            prefixIcon: Icons.person_outline,
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'El apellido es requerido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailController,
                          readOnly: true,
                          decoration: appInputDecoration(
                            label: 'Correo electrónico',
                            hint: 'tu@correo.com',
                            prefixIcon: Icons.email_outlined,
                            helperText:
                                'El email no puede modificarse desde acá',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneController,
                          decoration: appInputDecoration(
                            label: 'Teléfono',
                            hint: '+573001234567',
                            prefixIcon: Icons.phone_outlined,
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            AppFormSubmitBar(
              isSaving: false,
              onCancel: () => Navigator.of(context).pop(),
              onSave: _handleSave,
              saveLabel: 'Guardar',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({
    required String initials,
    required String name,
    required String role,
  }) {
    return AppGradientHeader(
      title: 'Mi perfil',
      subtitle: role.isEmpty ? 'Tu información personal' : role,
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
      ),
      hero: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.45),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role.isEmpty ? 'Editá tus datos abajo' : role,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;
    AppSnackbar.show(
      'Próximamente disponible',
      'La actualización de perfil llega en una próxima versión.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.info.withValues(alpha: 0.1),
      colorText: AppColors.textPrimary,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }
}
