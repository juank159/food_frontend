import 'package:dartz/dartz.dart';
import '../../../../core/config/constants/order_enums.dart';
import '../../../../core/error/failures.dart';
import '../entities/order.dart' as order_entity;
import '../repositories/order_repository.dart';

/// Create Order Use Case
/// Crea una nueva orden
class CreateOrderUseCase {
  final OrderRepository repository;

  CreateOrderUseCase(this.repository);

  Future<Either<Failure, order_entity.Order>> call({
    required OrderType orderType,
    OrderSource orderSource = OrderSource.pos,
    String? tableId,
    String? tableElementId, // Floor Plan Table Element ID
    String? tableLabel, // Etiqueta legible del destino ("Mostrador", etc.)
    /// ID de cuenta abierta. Si viene, el backend une el ticket a esa
    /// cuenta (en vez de buscar por mesa o crear una nueva), y relaja
    /// los requisitos de cliente — la cuenta es la unidad de pago.
    String? tabSessionId,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    Map<String, dynamic>? deliveryAddress,
    String? assignedTo,
    required List<Map<String, dynamic>> items,
    String? specialInstructions,
    double discountAmount = 0,
    double? discountPercentage,
    double deliveryFee = 0,
    double tipAmount = 0,
    double? taxAmount,
    PaymentMethod? paymentMethod,
    int? estimatedTime,
    Map<String, dynamic>? metadata,
  }) async {
    return await repository.createOrder(
      orderType: orderType,
      orderSource: orderSource,
      tableId: tableId,
      tableElementId: tableElementId,
      tableLabel: tableLabel,
      tabSessionId: tabSessionId,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      deliveryAddress: deliveryAddress,
      assignedTo: assignedTo,
      items: items,
      specialInstructions: specialInstructions,
      discountAmount: discountAmount,
      discountPercentage: discountPercentage,
      deliveryFee: deliveryFee,
      tipAmount: tipAmount,
      taxAmount: taxAmount,
      paymentMethod: paymentMethod,
      estimatedTime: estimatedTime,
      metadata: metadata,
    );
  }
}
