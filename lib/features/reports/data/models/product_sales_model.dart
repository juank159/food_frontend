import '../../domain/entities/product_sales_report.dart';

class ProductSalesItemModel {
  final String productId;
  final String productName;
  final String categoryName;
  final int unitsSold;
  final double totalRevenue;
  final int rank;

  const ProductSalesItemModel({
    required this.productId,
    required this.productName,
    required this.categoryName,
    required this.unitsSold,
    required this.totalRevenue,
    required this.rank,
  });

  factory ProductSalesItemModel.fromJson(Map<String, dynamic> json, int rank) {
    return ProductSalesItemModel(
      productId: json['product_id'] as String? ?? '',
      productName: json['product_name'] as String? ?? 'Sin nombre',
      categoryName: json['category_name'] as String? ?? 'Sin categoría',
      unitsSold: _parseInt(json['units_sold']),
      totalRevenue: _parseDouble(json['total_revenue']),
      rank: (json['rank'] is num ? (json['rank'] as num).toInt() : null) ?? rank,
    );
  }

  ProductSalesItem toEntity() => ProductSalesItem(
        productId: productId,
        productName: productName,
        categoryName: categoryName,
        unitsSold: unitsSold,
        totalRevenue: totalRevenue,
        rank: rank,
      );

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _parseDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
