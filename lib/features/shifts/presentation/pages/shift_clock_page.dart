import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../controllers/shift_controller.dart';

/// Pantalla central de turnos.
///
/// 2 estados:
///   - Sin turno abierto → CTA grande "Marcar entrada".
///   - Con turno abierto → cronómetro en vivo + CTA "Marcar salida".
///
/// Debajo: histórico de los últimos turnos.
class ShiftClockPage extends StatefulWidget {
  const ShiftClockPage({super.key});

  @override
  State<ShiftClockPage> createState() => _ShiftClockPageState();
}

class _ShiftClockPageState extends State<ShiftClockPage> {
  late final ShiftController controller;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    controller = Get.find<ShiftController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadCurrent();
      controller.loadHistory();
    });
    // Cronómetro en vivo — refresca cada 60s para actualizar el
    // duración mostrada cuando hay turno abierto.
    _tick = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mi turno'),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              controller.loadCurrent();
              controller.loadHistory();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await controller.loadCurrent();
            await controller.loadHistory();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Obx(() => _buildHero()),
              const SizedBox(height: 24),
              Text(
                'Turnos recientes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Obx(() => _buildHistory()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    if (controller.isLoading.value && controller.currentShift.value == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final s = controller.currentShift.value;
    return s == null ? _buildNoShift() : _buildOpenShift(s);
  }

  Widget _buildNoShift() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.access_time_rounded,
              size: 28,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No tenés un turno abierto',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Marcá entrada para empezar a registrar tu jornada.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: Obx(() {
              final mutating = controller.isMutating.value;
              return FilledButton.icon(
                onPressed: mutating ? null : () => _onClockIn(),
                icon: mutating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login),
                label: Text(
                  mutating ? 'Marcando...' : 'Marcar entrada',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenShift(s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, Color(0xFFE85A2A)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TURNO ACTIVO',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.formattedDuration,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Entrada: ${DateFormat('dd/MM HH:mm').format(s.clockIn.toLocal())}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: Obx(() {
              final mutating = controller.isMutating.value;
              return FilledButton.icon(
                onPressed: mutating ? null : () => _onClockOut(),
                icon: mutating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(Icons.logout, color: AppColors.primary),
                label: Text(
                  mutating ? 'Cerrando...' : 'Marcar salida',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.primary,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    final list = controller.history;
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'Sin turnos previos',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return Column(
      children: list
          .map(
            (s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.access_time,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE d MMM', 'es')
                              .format(s.clockIn.toLocal()),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${DateFormat('HH:mm').format(s.clockIn.toLocal())}'
                          ' → '
                          '${s.clockOut != null ? DateFormat('HH:mm').format(s.clockOut!.toLocal()) : 'abierto'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    s.formattedDuration,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _onClockIn() async {
    final notes = await _promptNotes(context, 'Marcar entrada');
    if (notes == null) return; // cancelado
    await controller.clockIn(notes: notes.isEmpty ? null : notes);
  }

  Future<void> _onClockOut() async {
    final notes = await _promptNotes(context, 'Marcar salida');
    if (notes == null) return;
    await controller.clockOut(notes: notes.isEmpty ? null : notes);
  }

  /// Dialog opcional con notas. Devuelve null si cancela.
  Future<String?> _promptNotes(BuildContext ctx, String title) async {
    final notesCtrl = TextEditingController();
    return showDialog<String>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: notesCtrl,
          decoration: const InputDecoration(
            labelText: 'Notas (opcional)',
            hintText: 'Turno tarde, cubrí a Juan...',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, notesCtrl.text.trim()),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}
