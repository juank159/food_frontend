import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/api_response_utils.dart';

/// Un turno de mostrador tal cual lo devuelve `GET /orders/tickets/board`
/// — proyección liviana, sin items/precios/cliente (ver
/// `OrdersService.findTicketsBoard` en el backend).
class _BoardTicket {
  final String id;
  final int ticketNumber;
  final OrderStatus status;
  final String? tableLabel;
  final int totalItems;
  final DateTime createdAt;

  const _BoardTicket({
    required this.id,
    required this.ticketNumber,
    required this.status,
    this.tableLabel,
    required this.totalItems,
    required this.createdAt,
  });

  factory _BoardTicket.fromJson(Map<String, dynamic> json) => _BoardTicket(
        id: json['id'] as String,
        ticketNumber: json['ticket_number'] as int,
        status: OrderStatus.fromString(json['status'] as String? ?? 'pending'),
        tableLabel: json['table_label'] as String?,
        totalItems: (json['total_items'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  /// `true` mientras cocina/mostrador lo está preparando.
  bool get isPreparing =>
      status == OrderStatus.pendingReview ||
      status == OrderStatus.pending ||
      status == OrderStatus.confirmed ||
      status == OrderStatus.preparing;

  bool get isReady => status == OrderStatus.ready;

  bool get isDelivered =>
      status == OrderStatus.delivered || status == OrderStatus.completed;
}

/// "Turnos activos" — tablero de turnos de mostrador de HOY, agrupado
/// por estado (preparando / listo / entregado) y ordenado por número.
///
/// Poll simple cada ~7s (mismo patrón que el tracking de QR y el
/// polling de Bre-B en esta app — no hay WebSockets en el backend).
/// Pensado para quedar abierto en un celular/tablet fijo en el
/// mostrador mientras se atiende.
class CounterTicketsBoardScreen extends StatefulWidget {
  const CounterTicketsBoardScreen({super.key});

  @override
  State<CounterTicketsBoardScreen> createState() =>
      _CounterTicketsBoardScreenState();
}

class _CounterTicketsBoardScreenState
    extends State<CounterTicketsBoardScreen> {
  late final Dio _dio;
  Timer? _pollingTimer;

  bool _loading = true;
  String? _error;
  List<_BoardTicket> _tickets = [];

  @override
  void initState() {
    super.initState();
    _dio = GetIt.I<Dio>();
    _load();
    _pollingTimer =
        Timer.periodic(const Duration(seconds: 7), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final res = await _dio.get('/orders/tickets/board');
      final body = ApiResponseUtils.object(res);
      final raw = (body['tickets'] as List?) ?? const [];
      final tickets = raw
          .cast<Map<String, dynamic>>()
          .map(_BoardTicket.fromJson)
          .toList();
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() => _error = ApiResponseUtils.errorMessage(e) ?? e.toString());
      }
      // En polling silencioso no mostramos error — un fallo de red
      // puntual no debe tapar el tablero con un mensaje; el próximo
      // tick reintenta solo.
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preparing = _tickets.where((t) => t.isPreparing).toList();
    final ready = _tickets.where((t) => t.isReady).toList();
    final delivered = _tickets.where((t) => t.isDelivered).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Turnos activos'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: () => _load())
              : _tickets.isEmpty
                  ? _EmptyView()
                  : RefreshIndicator(
                      onRefresh: () => _load(),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _section('Preparando', preparing, AppColors.warning),
                          _section('Listo — llamar al cliente', ready, AppColors.success),
                          _section('Entregado', delivered, AppColors.textSecondary),
                        ],
                      ),
                    ),
    );
  }

  Widget _section(String title, List<_BoardTicket> tickets, Color color) {
    if (tickets.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${title.toUpperCase()} (${tickets.length})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: tickets.map((t) => _ticketChip(t, color)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _ticketChip(_BoardTicket ticket, Color color) {
    return Container(
      width: 84,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1.6),
      ),
      child: Column(
        children: [
          Text(
            '${ticket.ticketNumber}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${ticket.totalItems} ${ticket.totalItems == 1 ? "item" : "items"}',
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.confirmation_number_outlined,
                size: 56, color: AppColors.textHint),
            const SizedBox(height: 12),
            const Text(
              'Todavía no hay turnos hoy',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Aparecen acá cuando cobrás con "Turno de mostrador" en Venta.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber, size: 56, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
