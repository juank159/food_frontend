import 'package:get/get.dart';
import '../../domain/entities/product_sales_report.dart';
import '../../domain/usecases/get_product_sales_usecase.dart';
import '../../../../core/config/formatters/datetime_formatter.dart';
import '../../../../core/utils/date_period.dart';

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

  // Límites en hora de Colombia real — antes se reimplementaban acá con
  // `DateTime.now()` del dispositivo, mismo bug ya corregido en
  // Cuentas Abiertas/Órdenes/Caja/otros reportes.
  void selectPreset(ProductSalesPreset p) {
    preset.value = p;
    switch (p) {
      case ProductSalesPreset.today:
        final range = resolveDatePeriod(DatePeriod.today);
        dateFrom.value = range.start!;
        dateTo.value = range.end!;
        break;
      case ProductSalesPreset.yesterday:
        final range = resolveDatePeriod(DatePeriod.yesterday);
        dateFrom.value = range.start!;
        dateTo.value = range.end!;
        break;
      case ProductSalesPreset.thisWeek:
        // Lunes de la semana actual, en Bogotá. `DatePeriod` no tiene
        // un preset de "esta semana" — se arma a mano pero anclado a
        // `nowInBogota()`, no al reloj del dispositivo.
        final today = resolveDatePeriod(DatePeriod.today);
        final bogotaNow = DateTimeFormatter.nowInBogota();
        final weekday = bogotaNow.weekday; // 1=lun, 7=dom
        final monday = today.start!.subtract(Duration(days: weekday - 1));
        dateFrom.value = monday;
        dateTo.value = today.end!;
        break;
      case ProductSalesPreset.thisMonth:
        final range = resolveDatePeriod(DatePeriod.thisMonth);
        dateFrom.value = range.start!;
        dateTo.value = range.end!;
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
