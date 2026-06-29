class ProductSalesItem {
  final String productId;
  final String productName;
  final String categoryName;
  final int unitsSold;
  final double totalRevenue;
  final int rank;

  const ProductSalesItem({
    required this.productId,
    required this.productName,
    required this.categoryName,
    required this.unitsSold,
    required this.totalRevenue,
    required this.rank,
  });
}

class ProductSalesReport {
  final List<ProductSalesItem> items;

  const ProductSalesReport({required this.items});

  factory ProductSalesReport.empty() =>
      const ProductSalesReport(items: []);

  ProductSalesItem? get topProduct =>
      items.isNotEmpty ? items.first : null;

  int get totalUnitsSold =>
      items.fold(0, (s, i) => s + i.unitsSold);

  double get totalRevenue =>
      items.fold(0, (s, i) => s + i.totalRevenue);

  int get distinctProducts => items.length;
}
