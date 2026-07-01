// lib/features/payments/data/datasources/payment_local_datasource.dart
import 'package:uuid/uuid.dart';
import '../../../../core/services/offline_queue_service.dart';

abstract class PaymentLocalDataSource {
  Future<void> enqueuePayment(Map<String, dynamic> createPaymentDto);
  List<QueueEntry> getPendingPayments();
}

class PaymentLocalDataSourceImpl implements PaymentLocalDataSource {
  final OfflineQueueService queue;

  PaymentLocalDataSourceImpl({required this.queue});

  @override
  Future<void> enqueuePayment(Map<String, dynamic> createPaymentDto) async {
    await queue.enqueue(
      QueueEntry(
        id: const Uuid().v4(),
        type: QueueOperationType.createPayment,
        payload: createPaymentDto,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  List<QueueEntry> getPendingPayments() {
    return queue
        .getAll()
        .where((e) => e.type == QueueOperationType.createPayment)
        .toList();
  }
}
