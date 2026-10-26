import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

import '../../../core/config/formatters/currency_formatter.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/input_formatters.dart';
import '../../../core/widgets/sheet_handle.dart';
import '../data/suppliers_models.dart';
import '../data/suppliers_repository.dart';

SuppliersRepository get _repo => GetIt.instance<SuppliersRepository>();

/// Crear o editar un proveedor. Devuelve `true` si se guardó (o quedó en
/// la cola sin internet).
Future<bool> showSupplierForm(
  BuildContext context, {
  Supplier? supplier,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _SupplierForm(supplier: supplier),
  );
  return saved ?? false;
}

class _SupplierForm extends StatefulWidget {
  final Supplier? supplier;
  const _SupplierForm({this.supplier});

  @override
  State<_SupplierForm> createState() => _SupplierFormState();
}

class _SupplierFormState extends State<_SupplierForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.supplier?.name ?? '');
  late final _taxId = TextEditingController(text: widget.supplier?.taxId ?? '');
  late final _contact = TextEditingController(
    text: widget.supplier?.contactName ?? '',
  );
  late final _phone = TextEditingController(text: widget.supplier?.phone ?? '');
  late final _email = TextEditingController(text: widget.supplier?.email ?? '');
  late final _terms = TextEditingController(
    text: '${widget.supplier?.paymentTermsDays ?? 0}',
  );
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _taxId, _contact, _phone, _email, _terms]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'tax_id': _taxId.text.trim(),
      'contact_name': _contact.text.trim(),
      'phone': _phone.text.trim(),
      if (_email.text.trim().isNotEmpty || widget.supplier != null)
        'email': _email.text.trim(),
      'payment_terms_days': int.tryParse(_terms.text.trim()) ?? 0,
    };
    if (widget.supplier == null) {
      body.removeWhere((k, v) => v is String && v.isEmpty);
    }
    final r = widget.supplier == null
        ? await _repo.createSupplier(body)
        : await _repo.updateSupplier(widget.supplier!.id, body);
    if (!mounted) return;
    setState(() => _saving = false);
    if (r.failed) {
      AppSnackbar.show('Proveedor', r.error!);
      return;
    }
    if (!r.synced) {
      AppSnackbar.show(
        'Proveedor',
        'Guardado sin internet · se sincroniza solo',
      );
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.supplier != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              Text(
                editing ? 'Editar proveedor' : 'Nuevo proveedor',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                autofocus: !editing,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                validator: (v) =>
                    (v ?? '').trim().length < 2 ? 'Escribí el nombre' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono / WhatsApp',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contact,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Persona de contacto',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _taxId,
                decoration: const InputDecoration(labelText: 'NIT / documento'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Correo'),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                      ? null
                      : 'Correo inválido';
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _terms,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Días de crédito',
                  helperText:
                      '0 = de contado. Con crédito, cada factura vence esos días después.',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Guardando…' : 'Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pagar a un proveedor (todo lo que se le debe o una compra puntual).
/// Devuelve `true` si se registró (o quedó en la cola).
Future<bool> showPaySupplierSheet(
  BuildContext context, {
  required Supplier supplier,
  required double owed,
  Purchase? purchase,
}) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _PaySheet(supplier: supplier, owed: owed, purchase: purchase),
  );
  return done ?? false;
}

class _PaySheet extends StatefulWidget {
  final Supplier supplier;
  final double owed;
  final Purchase? purchase;
  const _PaySheet({required this.supplier, required this.owed, this.purchase});

  @override
  State<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<_PaySheet> {
  late final _amount = TextEditingController(
    text: NumberFormatHelper.formatNumber(widget.owed.round()),
  );
  String _source = 'cash_register';
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final amount = (NumberFormatHelper.parseFormattedInt(_amount.text) ?? 0)
        .toDouble();
    if (amount <= 0) {
      AppSnackbar.show('Pago', 'Escribí cuánto vas a pagar');
      return;
    }
    if (amount > widget.owed + 0.5) {
      AppSnackbar.show(
        'Pago',
        'Es más de lo que se debe (${CurrencyFormatter.format(widget.owed)})',
      );
      return;
    }
    setState(() => _saving = true);
    final r = await _repo.paySupplier(widget.supplier.id, {
      'amount': amount,
      'payment_source': _source,
      if (widget.purchase != null) 'purchase_id': widget.purchase!.id,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (r.failed) {
      AppSnackbar.show('Pago', r.error!);
      return;
    }
    AppSnackbar.show(
      'Pago registrado',
      r.synced
          ? '${CurrencyFormatter.format(amount)} a ${widget.supplier.name}'
          : 'Guardado sin internet · se sincroniza solo',
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          Text(
            'Pagar a ${widget.supplier.name}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            widget.purchase != null
                ? 'Esta compra debe ${CurrencyFormatter.format(widget.owed)}'
                : 'Se le debe ${CurrencyFormatter.format(widget.owed)}. El pago se aplica a las compras más viejas primero.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsSeparatorInputFormatter()],
            decoration: const InputDecoration(
              labelText: 'Monto',
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _source,
            decoration: const InputDecoration(
              labelText: '¿Con qué plata se paga?',
            ),
            items: [
              for (final e in PaymentSources.all.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _source = v ?? 'cash_register'),
          ),
          if (_source == 'cash_register')
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Sale del efectivo de tu caja abierta (cuadra en el cierre).',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _pay,
            child: Text(_saving ? 'Registrando…' : 'Registrar pago'),
          ),
        ],
      ),
    );
  }
}
