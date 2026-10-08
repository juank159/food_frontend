import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../controllers/auth_controller.dart';
import '../widgets/code_expiry_timer.dart';

/// Último paso de "Crear mi restaurante": confirma el código de 6
/// dígitos que mandó `POST /auth/signup` y, si es correcto, arranca
/// sesión de verdad (`AuthController.confirmSignup` → `/auth/signup/confirm`).
///
/// El email llega por `Get.arguments['email']` (lo manda
/// `AuthController.signUp` al navegar acá) o por `Get.parameters['email']`
/// como fallback.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const int _otpLength = 6;

  final _authController = Get.find<AuthController>();
  final _timerKey = GlobalKey<CodeExpiryTimerState>();
  late final List<TextEditingController> _otpControllers;
  late final List<FocusNode> _focusNodes;
  bool _isLoading = false;
  bool _isResending = false;
  late final String _email;

  @override
  void initState() {
    super.initState();
    _otpControllers =
        List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());
    final paramEmail = Get.parameters['email'];
    final argsMap = Get.arguments;
    final argEmail = argsMap is Map ? argsMap['email'] as String? : null;
    _email = paramEmail ?? argEmail ?? '';
  }

  @override
  void dispose() {
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Container(
            height: 240,
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeroBar(),
                  const SizedBox(height: 16),
                  _buildHero(),
                  const SizedBox(height: 24),
                  _buildFormCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBar() {
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

  Widget _buildHero() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Verificá tu email',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _email.isEmpty
              ? 'Te enviamos un código a tu correo'
              : 'Te enviamos un código a $_email',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
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
          const Text(
            'Ingresá los 6 dígitos del código que recibiste por email.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: CodeExpiryTimer(
              key: _timerKey,
              onExpired: () => setState(() {}),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_otpLength, (i) => _buildOtpInput(i)),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isLoading || (_timerKey.currentState?.isExpired ?? false)
                ? null
                : _handleVerify,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.check, size: 18),
            label: Text(
              _isLoading ? 'Verificando…' : 'Verificar',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: _isResending ? null : _handleResend,
              icon: _isResending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 16),
              label: Text(
                _isResending ? 'Reenviando…' : 'Reenviar código',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpInput(int index) {
    return SizedBox(
      width: 44,
      height: 56,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: AppColors.background,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < _otpLength - 1) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }

  Future<void> _handleVerify() async {
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length < _otpLength) {
      AppSnackbar.show(
        'Código incompleto',
        'Ingresá los 6 dígitos del código.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.warning.withValues(alpha: 0.1),
        colorText: AppColors.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return;
    }
    setState(() => _isLoading = true);

    final error =
        await _authController.confirmSignup(email: _email, code: code);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) return; // éxito → el controller ya navegó a /home

    AppSnackbar.show(
      'No se pudo verificar',
      error,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.error.withValues(alpha: 0.1),
      colorText: AppColors.textPrimary,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  Future<void> _handleResend() async {
    setState(() => _isResending = true);

    final error = await _authController.resendSignupCode(email: _email);

    if (!mounted) return;
    setState(() => _isResending = false);

    if (error != null) {
      AppSnackbar.show(
        'No se pudo reenviar',
        error,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error.withValues(alpha: 0.1),
        colorText: AppColors.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return;
    }

    for (final c in _otpControllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
    _timerKey.currentState?.restart();
    setState(() {}); // refleja que ya no está expirado (reactiva "Verificar")

    AppSnackbar.show(
      'Código reenviado',
      'Revisá tu bandeja de entrada.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.info.withValues(alpha: 0.1),
      colorText: AppColors.textPrimary,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }
}
