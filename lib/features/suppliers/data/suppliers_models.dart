double _num(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

double? _numOrNull(dynamic v) => v == null ? null : _num(v);

DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v) : null;

/// Origen del dinero con el que se paga (mismo catálogo que los gastos).
class PaymentSources {
  static const all = <String, String>{
    'cash_register': 'Efectivo de la caja',
    'bank_account': 'Cuenta bancaria / transferencia',
    'petty_cash': 'Caja menor',
    'credit_card': 'Tarjeta',
    'personal': 'Dinero personal del dueño',
  };
  static String label(String code) => all[code] ?? code;
}

class Supplier {
  final String id;
  final String name;
  final String? taxId;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? address;
  final int paymentTermsDays;
  final String? notes;
  final bool isActive;
  final double balanceOwed;
  final DateTime? lastPurchaseAt;
  final int purchasesCount;

  /// Creado sin internet, todavía en la cola.
  final bool pendingSync;

  const Supplier({
    required this.id,
    required this.name,
    this.taxId,
    this.contactName,
    this.phone,
    this.email,
    this.address,
    this.paymentTermsDays = 0,
    this.notes,
    this.isActive = true,
    this.balanceOwed = 0,
    this.lastPurchaseAt,
    this.purchasesCount = 0,
    this.pendingSync = false,
  });

  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
    id: j['id'] as String,
    name: j['name'] as String? ?? 'Proveedor',
    taxId: j['tax_id'] as String?,
    contactName: j['contact_name'] as String?,
    phone: j['phone'] as String?,
    email: j['email'] as String?,
    address: j['address'] as String?,
    paymentTermsDays: (j['payment_terms_days'] as num?)?.toInt() ?? 0,
    notes: j['notes'] as String?,
    isActive: j['is_active'] as bool? ?? true,
    balanceOwed: _num(j['balance_owed']),
    lastPurchaseAt: _date(j['last_purchase_at']),
    purchasesCount: (j['purchases_count'] as num?)?.toInt() ?? 0,
    pendingSync: j['pending_sync'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tax_id': taxId,
    'contact_name': contactName,
    'phone': phone,
    'email': email,
    'address': address,
    'payment_terms_days': paymentTermsDays,
    'notes': notes,
    'is_active': isActive,
    'balance_owed': balanceOwed,
    'last_purchase_at': lastPurchaseAt?.toIso8601String(),
    'purchases_count': purchasesCount,
    if (pendingSync) 'pending_sync': true,
  };
}

class PurchaseLine {
  final String id;
  final String ingredientId;
  final String? ingredientName;
  final String? unit;
  final double quantityOrdered;
  final double? quantityReceived;
  final double? unitCost;
  final double lineTotal;

  const PurchaseLine({
    required this.id,
    required this.ingredientId,
    this.ingredientName,
    this.unit,
    required this.quantityOrdered,
    this.quantityReceived,
    this.unitCost,
    required this.lineTotal,
  });

  factory PurchaseLine.fromJson(Map<String, dynamic> j) => PurchaseLine(
    id: j['id'] as String? ?? '',
    ingredientId: j['ingredient_id'] as String,
    ingredientName: j['ingredient_name'] as String?,
    unit: j['unit'] as String?,
    quantityOrdered: _num(j['quantity_ordered']),
    quantityReceived: _numOrNull(j['quantity_received']),
    unitCost: _numOrNull(j['unit_cost']),
    lineTotal: _num(j['line_total']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'ingredient_id': ingredientId,
    'ingredient_name': ingredientName,
    'unit': unit,
    'quantity_ordered': quantityOrdered,
    'quantity_received': quantityReceived,
    'unit_cost': unitCost,
    'line_total': lineTotal,
  };
}

class PurchasePayment {
  final String id;
  final double amount;
  final double applied;
  final String paymentSource;
  final DateTime? paidAt;

  const PurchasePayment({
    required this.id,
    required this.amount,
    required this.applied,
    required this.paymentSource,
    this.paidAt,
  });

  factory PurchasePayment.fromJson(Map<String, dynamic> j) => PurchasePayment(
    id: j['id'] as String? ?? '',
    amount: _num(j['amount']),
    applied: _num(j['applied'] ?? j['amount']),
    paymentSource: j['payment_source'] as String? ?? 'cash_register',
    paidAt: _date(j['paid_at']),
  );
}

class Purchase {
  final String id;
  final String status; // ordered | received | cancelled
  final String? supplierId;
  final String? supplierName;
  final String? invoiceNumber;
  final DateTime? orderedAt;
  final DateTime? receivedAt;
  final DateTime? dueDate;
  final double total;
  final double paidAmount;
  final double balance;
  final String paymentStatus; // pending | partial | paid
  final String? notes;
  final List<PurchaseLine> lines;
  final List<PurchasePayment> payments;
  final bool pendingSync;

  const Purchase({
    required this.id,
    required this.status,
    this.supplierId,
    this.supplierName,
    this.invoiceNumber,
    this.orderedAt,
    this.receivedAt,
    this.dueDate,
    required this.total,
    required this.paidAmount,
    required this.balance,
    required this.paymentStatus,
    this.notes,
    this.lines = const [],
    this.payments = const [],
    this.pendingSync = false,
  });

  bool get isOrder => status == 'ordered';
  bool get isReceived => status == 'received';
  bool get isCancelled => status == 'cancelled';
  bool get isOverdue =>
      isReceived &&
      balance > 0.004 &&
      dueDate != null &&
      dueDate!.isBefore(DateTime.now().subtract(const Duration(days: 1)));

  factory Purchase.fromJson(Map<String, dynamic> j) {
    final supplier = j['supplier'];
    return Purchase(
      id: j['id'] as String,
      status: j['status'] as String? ?? 'received',
      supplierId: j['supplier_id'] as String?,
      supplierName: supplier is Map
          ? supplier['name'] as String?
          : j['supplier_name'] as String?,
      invoiceNumber: j['invoice_number'] as String?,
      orderedAt: _date(j['ordered_at']),
      receivedAt: _date(j['received_at']),
      dueDate: _date(j['due_date']),
      total: _num(j['total']),
      paidAmount: _num(j['paid_amount']),
      balance: _num(j['balance']),
      paymentStatus: j['payment_status'] as String? ?? 'pending',
      notes: j['notes'] as String?,
      lines: (j['lines'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => PurchaseLine.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      payments: (j['payments'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => PurchasePayment.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      pendingSync: j['pending_sync'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status,
    'supplier_id': supplierId,
    'supplier_name': supplierName,
    'invoice_number': invoiceNumber,
    'ordered_at': orderedAt?.toIso8601String(),
    'received_at': receivedAt?.toIso8601String(),
    'due_date': dueDate?.toIso8601String(),
    'total': total,
    'paid_amount': paidAmount,
    'balance': balance,
    'payment_status': paymentStatus,
    'notes': notes,
    'lines': lines.map((l) => l.toJson()).toList(),
    if (pendingSync) 'pending_sync': true,
  };
}

class PurchaseSuggestion {
  final String ingredientId;
  final String name;
  final String unit;
  final double currentStock;
  final double minStock;
  final double dailyUsage;
  final double? daysLeft;
  final double suggestedQuantity;
  final String? lastSupplierId;
  final String? lastSupplier;
  final double unitCost;
  final double estimatedCost;

  const PurchaseSuggestion({
    required this.ingredientId,
    required this.name,
    required this.unit,
    required this.currentStock,
    required this.minStock,
    required this.dailyUsage,
    this.daysLeft,
    required this.suggestedQuantity,
    this.lastSupplierId,
    this.lastSupplier,
    required this.unitCost,
    required this.estimatedCost,
  });

  factory PurchaseSuggestion.fromJson(Map<String, dynamic> j) =>
      PurchaseSuggestion(
        ingredientId: j['ingredient_id'] as String,
        name: j['name'] as String? ?? 'Insumo',
        unit: j['unit'] as String? ?? 'unit',
        currentStock: _num(j['current_stock']),
        minStock: _num(j['min_stock']),
        dailyUsage: _num(j['daily_usage']),
        daysLeft: _numOrNull(j['days_left']),
        suggestedQuantity: _num(j['suggested_quantity']),
        lastSupplierId: j['last_supplier_id'] as String?,
        lastSupplier: j['last_supplier'] as String?,
        unitCost: _num(j['unit_cost']),
        estimatedCost: _num(j['estimated_cost']),
      );
}

class SupplierSpend {
  final String? supplierId;
  final String name;
  final int purchasesCount;
  final double total;
  final double owed;

  const SupplierSpend({
    this.supplierId,
    required this.name,
    required this.purchasesCount,
    required this.total,
    required this.owed,
  });

  factory SupplierSpend.fromJson(Map<String, dynamic> j) => SupplierSpend(
    supplierId: j['supplier_id'] as String?,
    name: j['name'] as String? ?? 'Sin proveedor',
    purchasesCount: (j['purchases_count'] as num?)?.toInt() ?? 0,
    total: _num(j['total']),
    owed: _num(j['owed']),
  );
}

class PricePoint {
  final DateTime? at;
  final double unitCost;
  final double quantity;
  final String? supplier;

  const PricePoint({
    this.at,
    required this.unitCost,
    required this.quantity,
    this.supplier,
  });

  factory PricePoint.fromJson(Map<String, dynamic> j) => PricePoint(
    at: _date(j['at']),
    unitCost: _num(j['unit_cost']),
    quantity: _num(j['quantity']),
    supplier: j['supplier'] as String?,
  );
}
