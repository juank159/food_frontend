import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/config/formatters/currency_formatter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/input_formatters.dart';
import '../../../../core/widgets/app_form_section.dart';

/// Datos capturados por el widget. Se devuelven al caller en `onSave`
/// para que actualice el form controller con TODO de una sola vez.
///
/// Los campos de delivery solo se llenan cuando `orderType == delivery`.
class CustomerInfoResult {
  final String? name;
  final String? phone;
  final String? email;
  final String? deliveryStreet;
  final String? deliveryCity;
  final String? deliveryNotes;
  final double? deliveryFee;

  const CustomerInfoResult({
    this.name,
    this.phone,
    this.email,
    this.deliveryStreet,
    this.deliveryCity,
    this.deliveryNotes,
    this.deliveryFee,
  });
}

/// Captura datos del cliente — usado dentro de un Dialog desde el flujo
/// de creación de orden.
///
/// La complejidad clave: los campos REQUERIDOS y MOSTRADOS varían según
/// `orderType`:
///
///   - takeaway → nombre + teléfono (recomendado pero opcional). Sin
///     dirección, sin fee.
///   - delivery → nombre, teléfono **obligatorio**, dirección
///     **obligatoria** (calle + ciudad/barrio), costo de envío, notas.
///
/// La idea es que el operario no pueda crear una orden delivery sin
/// los datos mínimos para que el repartidor pueda entregarla.
class CustomerInfoWidget extends StatefulWidget {
  final OrderType orderType;
  final String? initialName;
  final String? initialPhone;
  final String? initialEmail;
  final String? initialDeliveryStreet;
  final String? initialDeliveryCity;
  final String? initialDeliveryNotes;
  final double? initialDeliveryFee;
  final ValueChanged<CustomerInfoResult> onSave;

  const CustomerInfoWidget({
    super.key,
    required this.orderType,
    this.initialName,
    this.initialPhone,
    this.initialEmail,
    this.initialDeliveryStreet,
    this.initialDeliveryCity,
    this.initialDeliveryNotes,
    this.initialDeliveryFee,
    required this.onSave,
  });

  bool get _isDelivery => orderType == OrderType.delivery;

  @override
  State<CustomerInfoWidget> createState() => _CustomerInfoWidgetState();
}

class _CustomerInfoWidgetState extends State<CustomerInfoWidget> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  late final TextEditingController _streetController;
  late final TextEditingController _cityController;
  late final TextEditingController _notesController;
  late final TextEditingController _feeController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _emailController = TextEditingController(text: widget.initialEmail);

    _streetController =
        TextEditingController(text: widget.initialDeliveryStreet);
    _cityController = TextEditingController(text: widget.initialDeliveryCity);
    _notesController = TextEditingController(text: widget.initialDeliveryNotes);
    _feeController = TextEditingController(
      text: widget.initialDeliveryFee != null && widget.initialDeliveryFee! > 0
          ? NumberFormatHelper.formatNumber(widget.initialDeliveryFee!.toInt())
          : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _notesController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        // SingleChildScrollView para que en mobile chico con teclado
        // abierto el contenido siga siendo accesible.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              ..._buildCustomerFields(),
              if (widget._isDelivery) ...[
                const SizedBox(height: 18),
                _buildSectionDivider('Dirección de entrega'),
                const SizedBox(height: 12),
                ..._buildDeliveryFields(),
              ],
              const SizedBox(height: 12),
              const Text(
                '* Campo requerido',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textHint,
                ),
              ),
              const SizedBox(height: 18),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────── Header ──────────────────────────

  Widget _buildHeader() {
    final isDelivery = widget._isDelivery;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: (isDelivery ? AppColors.warning : AppColors.info)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(
            isDelivery ? Icons.delivery_dining : Icons.person_add_alt_1,
            color: isDelivery ? AppColors.warning : AppColors.info,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isDelivery ? 'Datos para entregar' : 'Datos del cliente',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isDelivery
                    ? 'Sin estos datos el repartidor no puede entregar'
                    : 'Nombre + teléfono para contactar al cliente',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 20),
          color: AppColors.textSecondary,
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildSectionDivider(String label) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(height: 1, color: AppColors.divider),
        ),
      ],
    );
  }

  // ─────────────────────── Customer fields ───────────────────────

  List<Widget> _buildCustomerFields() {
    final isDelivery = widget._isDelivery;
    final phoneLabel = isDelivery ? 'Teléfono *' : 'Teléfono';
    return [
      TextFormField(
        controller: _nameController,
        textCapitalization: TextCapitalization.words,
        decoration: appInputDecoration(
          label: 'Nombre completo *',
          hint: 'Juan Pérez',
          prefixIcon: Icons.person_outline,
        ),
        validator: (value) {
          final v = (value ?? '').trim();
          if (v.isEmpty) return 'El nombre es requerido';
          if (v.length < 3) return 'Mínimo 3 caracteres';
          return null;
        },
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        // Solo dígitos, espacios y `+` para que `_normalizePhone` sea
        // determinista — sin paréntesis ni guiones (el backend usa regex
        // E.164 estricto: ^\+?[1-9]\d{1,14}$).
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]')),
        ],
        decoration: appInputDecoration(
          label: phoneLabel,
          hint: '+57 300 123 4567',
          prefixIcon: Icons.phone_outlined,
        ),
        validator: (value) {
          final normalized = _normalizePhone(value);
          if (isDelivery && normalized.isEmpty) {
            return 'El teléfono es requerido para entrega';
          }
          if (normalized.isNotEmpty) {
            // 7 dígitos mínimo (cubre fijos locales y celulares LATAM
            // con o sin prefijo país). El backend E.164 acepta hasta 15.
            final digits = normalized.replaceAll('+', '');
            if (digits.length < 7) return 'Mínimo 7 dígitos';
            if (digits.length > 15) return 'Máximo 15 dígitos';
            // El primer dígito significativo no puede ser 0 (regex
            // backend exige `[1-9]` después del + opcional).
            if (digits.startsWith('0')) {
              return 'No puede empezar con 0';
            }
          }
          return null;
        },
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        decoration: appInputDecoration(
          label: 'Email',
          hint: 'cliente@correo.com',
          prefixIcon: Icons.email_outlined,
        ),
        validator: (value) {
          if (value != null && value.isNotEmpty) {
            final regex = RegExp(
              r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
            );
            if (!regex.hasMatch(value)) return 'Email no válido';
          }
          return null;
        },
      ),
    ];
  }

  // ─────────────────────── Delivery fields ───────────────────────

  List<Widget> _buildDeliveryFields() {
    return [
      TextFormField(
        controller: _streetController,
        textCapitalization: TextCapitalization.sentences,
        decoration: appInputDecoration(
          label: 'Dirección *',
          hint: 'Calle 12 #34-56, apto 502',
          prefixIcon: Icons.home_outlined,
        ),
        validator: (value) {
          final v = (value ?? '').trim();
          if (v.isEmpty) return 'La dirección es requerida';
          if (v.length < 5) return 'Mínimo 5 caracteres';
          return null;
        },
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _cityController,
        textCapitalization: TextCapitalization.words,
        decoration: appInputDecoration(
          label: 'Barrio / Sector',
          hint: 'Chapinero, La 14, etc.',
          prefixIcon: Icons.location_city_outlined,
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _notesController,
        textCapitalization: TextCapitalization.sentences,
        maxLines: 2,
        decoration: appInputDecoration(
          label: 'Referencia / Notas para el repartidor',
          hint: 'Frente al parque, portería azul, etc.',
          prefixIcon: Icons.info_outline,
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _feeController,
        keyboardType: TextInputType.number,
        // Mismo formatter de miles que usa el split payment. Trabajamos
        // en entero (pesos enteros COP) — sin centavos.
        inputFormatters: [ThousandsSeparatorInputFormatter()],
        decoration: appInputDecoration(
          label: 'Costo de envío',
          hint: '5.000',
          prefixIcon: Icons.local_shipping_outlined,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return null; // opcional
          final parsed = NumberFormatHelper.parseFormattedInt(value);
          if (parsed == null) return 'Valor inválido';
          if (parsed < 0) return 'No puede ser negativo';
          if (parsed > 1000000) return 'Máximo \$1.000.000';
          return null;
        },
      ),
      // Hint con preview del fee formateado en moneda local — confirma
      // visualmente que el monto está bien antes de guardar.
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: _feeController,
        builder: (_, value, __) {
          final parsed = NumberFormatHelper.parseFormattedInt(value.text);
          if (parsed == null || parsed == 0) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(
              'Envío: ${CurrencyFormatter.format(parsed.toDouble())}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        },
      ),
    ];
  }

  // ────────────────────────── Actions ──────────────────────────

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cancelar'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: _handleSave,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.check, size: 18),
            label: const Text(
              'Guardar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  // ────────────────────────── Helpers ──────────────────────────

  /// Normaliza el teléfono al formato que el backend acepta:
  /// `+?[1-9]\d{1,14}`. Quita TODO lo que no sea dígito (excepto un `+`
  /// inicial). Sin esto, el backend rechaza `(300) 123-4567` con un 400.
  String _normalizePhone(String? raw) {
    if (raw == null) return '';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final hasPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    return hasPlus ? '+$digits' : digits;
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    String? nullIfEmpty(String s) => s.isEmpty ? null : s;

    final name = _nameController.text.trim();
    final phone = _normalizePhone(_phoneController.text);
    final email = _emailController.text.trim();

    final isDelivery = widget._isDelivery;
    final street = isDelivery ? _streetController.text.trim() : '';
    final city = isDelivery ? _cityController.text.trim() : '';
    final notes = isDelivery ? _notesController.text.trim() : '';
    final feeRaw =
        isDelivery ? _feeController.text.trim() : '';
    final feeParsed = feeRaw.isEmpty
        ? null
        : NumberFormatHelper.parseFormattedInt(feeRaw)?.toDouble();

    widget.onSave(
      CustomerInfoResult(
        name: nullIfEmpty(name),
        phone: nullIfEmpty(phone),
        email: nullIfEmpty(email),
        deliveryStreet: nullIfEmpty(street),
        deliveryCity: nullIfEmpty(city),
        deliveryNotes: nullIfEmpty(notes),
        deliveryFee: feeParsed,
      ),
    );
  }
}
