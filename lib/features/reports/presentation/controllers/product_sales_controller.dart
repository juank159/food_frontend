import 'package:get/get.dart';
import '../../domain/entities/product_sales_report.dart';
import '../../domain/usecases/get_product_sales_usecase.dart';

enum ProductSalesPreset { today, yesterday, thisWeek, thisMonth }

class ProductSalesController extends GetxController {
  final GetProductSalesUseCase getProductSalesUseCase;

  ProductSalesController({required this.getProductSalesUseCase});

  final Rx<ProductSalesReport> report = ProductSalesReport.empty().obs;
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;
  final Rx<ProductSalesPreset> preset = ProductSalesPreset.today.obs;
  final Rx<DateTime> dateFrom = DateTime.now().obs;
  final Rx<DateTime> dateTo = DateTime.now().obs;

  @override
  void onInit() {
    super.onInit();
    selectPreset(ProductSalesPreset.today);
  }

  void selectPreset(ProductSalesPreset p) {
    preset.value = p;
    final now = DateTime.now();
    switch (p) {
      case ProductSalesPreset.today:
        dateFrom.value = DateTime(now.year, now.month, now.day);
        dateTo.value = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case ProductSalesPreset.yesterday:
        final y = now.subtract(const Duration(days: 1));
        dateFrom.value = DateTime(y.year, y.month, y.day);
        dateTo.value = DateTime(y.year, y.month, y.day, 23, 59, 59);
        break;
      case ProductSalesPreset.thisWeek:
        // lunes de la semana actual
        final weekday = now.weekday; // 1=lun, 7=dom
        final monday = now.subtract(Duration(days: weekday - 1));
        dateFrom.value = DateTime(monday.year, monday.month, monday.day);
        dateTo.value = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case ProductSalesPreset.thisMonth:
        dateFrom.value = DateTime(now.year, now.month, 1);
        dateTo.value = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
    }
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = '';
    final result = await getProductSalesUseCase(
      dateFrom: dateFrom.value,
      dateTo: dateTo.value,
    );
    result.fold(
      (f) => error.value = f.message,
      (r) => report.value = r,
    );
    isLoading.value = false;
  }

  @override
  Future<void> refresh() => load();

  String get presetLabel {
    switch (preset.value) {
      case ProductSalesPreset.today:
        return 'Hoy';
      case ProductSalesPreset.yesterday:
        return 'Ayer';
      case ProductSalesPreset.thisWeek:
        return 'Esta semana';
      case ProductSalesPreset.thisMonth:
        return 'Este mes';
    }
  }
}
