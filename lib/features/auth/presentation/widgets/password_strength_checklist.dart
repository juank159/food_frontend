import 'package:flutter/material.dart';
import '../../../../core/config/theme/app_colors.dart';

/// Checklist de requisitos de contraseña que se va marcando en tiempo
/// real a medida que el usuario tipea — mismas reglas que
/// `Validators.password` (y el DTO del backend): mínimo 8 caracteres,
/// mayúscula, minúscula, número y carácter especial.
///
/// Escucha los `TextEditingController` directamente (son `Listenable`)
/// en vez de depender de que el widget padre haga `setState` en cada
/// tecla — así el checklist se repinta solo, sin tocar el resto de la
/// pantalla.
class PasswordStrengthChecklist extends StatelessWidget {
  final TextEditingController passwordController;
  final TextEditingController? confirmController;

  const PasswordStrengthChecklist({
    super.key,
    required this.passwordController,
    this.confirmController,
  });

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[
      passwordController,
      if (confirmController != null) confirmController!,
    ];

    return AnimatedBuilder(
      animation: Listenable.merge(listenables),
      builder: (context, _) {
        final password = passwordController.text;
        final confirm = confirmController?.text;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Rule(label: 'Mínimo 8 caracteres', met: password.length >= 8),
            _Rule(
              label: 'Una mayúscula (A-Z)',
              met: password.contains(RegExp(r'[A-Z]')),
            ),
            _Rule(
              label: 'Una minúscula (a-z)',
              met: password.contains(RegExp(r'[a-z]')),
            ),
            _Rule(
              label: 'Un número (0-9)',
              met: password.contains(RegExp(r'[0-9]')),
            ),
            _Rule(
              label: 'Un carácter especial (@\$!%*?&)',
              met: password.contains(RegExp(r'[@$!%*?&]')),
            ),
            if (confirmController != null)
              _Rule(
                label: 'Las contraseñas coinciden',
                met: password.isNotEmpty && password == confirm,
              ),
          ],
        );
      },
    );
  }
}

class _Rule extends StatelessWidget {
  final String label;
  final bool met;

  const _Rule({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    final color = met ? AppColors.success : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Icon(
              met ? Icons.check_circle : Icons.radio_button_unchecked,
              key: ValueKey(met),
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: color,
                fontWeight: met ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
