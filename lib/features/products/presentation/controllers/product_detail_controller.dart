import 'package:get/get.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/get_product_by_id_usecase.dart';

/// Controller del detalle de producto.
///
/// Recibe el `id` por `Get.parameters['id']`. Si la pantalla anterior pasó
/// el objeto completo en `Get.arguments`, lo usa de cache para mostrar
/// algo al instante mientras el GET resuelve. Si no hay arguments, hace
/// el fetch completo.
class ProductDetailController extends GetxController {
  final GetProductByIdUseCase getProductByIdUseCase;

  ProductDetailController({required this.getProductByIdUseCase});

  final Rx<Product?> product = Rx<Product?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  String? _id;

  @override
  void onInit() {
    super.onInit();
    _id = Get.parameters['id'];
    final cached = Get.arguments;
    if (cached is Product) {
      product.value = cached;
      _id ??= cached.id;
    }
    if (_id != null) load();
  }

  Future<void> load() async {
    if (_id == null) {
      errorMessage.value = 'ID de producto inválido';
      return;
    }
    isLoading.value = true;
    errorMessage.value = '';
    final result = await getProductByIdUseCase(_id!);
    result.fold(
      (failure) {
        errorMessage.value = failure.message;
      },
      (loaded) {
        product.value = loaded;
      },
    );
    isLoading.value = false;
  }

  /// Re-fetch del producto. No usamos el nombre `refresh()` porque
  /// `GetxController` ya expone uno (de `ListNotifier`) y no podemos
  /// cambiarle la firma a `Future<void>`.
  Future<void> reload() => load();
}
