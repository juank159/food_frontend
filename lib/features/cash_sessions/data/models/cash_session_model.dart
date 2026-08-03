import '../../domain/entities/cash_session.dart';

/// Model con `fromJson` defensivo:
/// - Decimals como String (Postgres) o num.
/// - FKs que pueden venir expandidos (objeto) o como UUID string.
class CashSessionModel {
  final String id;
  final String openedBy;
  final String? openedByName;
  final String openedAt;
  final double openingAmount;

  final String? closedBy;
  final String? closedByName;
  final String? closedAt;
  final double? closingAmountCounted;

  final double totalCashCollected;
  final int totalPaymentsCount;
  final double totalCashExpenses;
  final double totalOtherCollected;
  final int totalOtherCount;
  final double? expectedAmount;
  final double? difference;

  final String status;
  final String? notes;
  final String? closingNotes;

  const CashSessionModel({
    required this.id,
    required this.openedBy,
    this.openedByName,
    required this.openedAt,
    required this.openingAmount,
    this.closedBy,
    this.closedByName,
    this.closedAt,
    this.closingAmountCounted,
    required this.totalCashCollected,
    required this.totalPaymentsCount,
    this.totalCashExpenses = 0,
    this.totalOtherCollected = 0,
    this.totalOtherCount = 0,
    this.expectedAmount,
    this.difference,
    required this.status,
    this.notes,
    this.closingNotes,
  });

  factory CashSessionModel.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    double? parseNumNullable(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    // FKs que pueden venir como UUID string o como objeto User (cuando
    // TypeORM expande la relación tras save). Patrón de la memoria
    // `feedback_typeorm_relation_expansion`.
    String? parseIdOrObject(dynamic v) {
      if (v == null) return null;
      if (v is String) return v;
      if (v is Map<String, dynamic>) {
        final id = v['id'];
        return id is String ? id : null;
      }
      return null;
    }

    String? parseName(dynamic flat, dynamic obj) {
      if (flat is String && flat.isNotEmpty) return flat;
      if (obj is Map<String, dynamic>) {
        final n = obj['full_name'];
        return n is String ? n : null;
      }
      return null;
    }

    final openedByUser = json['opened_by_user'] as Map<String, dynamic>?;
    final closedByUser = json['closed_by_user'] as Map<String, dynamic>?;

    return CashSessionModel(
      id: json['id'] as String,
      openedBy: parseIdOrObject(json['opened_by']) ?? '',
      openedByName: parseName(json['opened_by_name'], openedByUser),
      openedAt: json['opened_at'] as String,
      openingAmount: parseNum(json['opening_amount']),
      closedBy: parseIdOrObject(json['closed_by']),
      closedByName: parseName(json['closed_by_name'], closedByUser),
      closedAt: json['closed_at'] as String?,
      closingAmountCounted:
          parseNumNullable(json['closing_amount_counted']),
      totalCashCollected: parseNum(json['total_cash_collected']),
      totalPaymentsCount:
          (json['total_payments_count'] as num?)?.toInt() ?? 0,
      totalCashExpenses: parseNum(json['total_cash_expenses']),
      totalOtherCollected: parseNum(json['total_other_collected']),
      totalOtherCount:
          (json['total_other_count'] as num?)?.toInt() ?? 0,
      expectedAmount: parseNumNullable(json['expected_amount']),
      difference: parseNumNullable(json['difference']),
      status: json['status'] as String? ?? 'open',
      notes: json['notes'] as String?,
      closingNotes: json['closing_notes'] as String?,
    );
  }

  CashSession toEntity() {
    return CashSession(
      id: id,
      openedBy: openedBy,
      openedByName: openedByName,
      openedAt: DateTime.parse(openedAt),
      openingAmount: openingAmount,
      closedBy: closedBy,
      closedByName: closedByName,
      closedAt: closedAt != null ? DateTime.parse(closedAt!) : null,
      closingAmountCounted: closingAmountCounted,
      totalCashCollected: totalCashCollected,
      totalPaymentsCount: totalPaymentsCount,
      totalCashExpenses: totalCashExpenses,
      totalOtherCollected: totalOtherCollected,
      totalOtherCount: totalOtherCount,
      expectedAmount: expectedAmount,
      difference: difference,
      status: CashSessionStatus.fromString(status),
      notes: notes,
      closingNotes: closingNotes,
    );
  }
}
