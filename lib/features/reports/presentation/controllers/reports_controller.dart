import 'package:get/get.dart';

/// Reports Hub Controller
///
/// Ultra-liviano: la pantalla `ReportsPage` es un hub estático que sólo
/// despacha a los sub-reportes. Mantenemos un controller dedicado igual
/// para conservar la simetría con el resto de los módulos (todos tienen
/// binding+controller) y para dar un anclaje futuro si quisiéramos cargar
/// datos en el hub (ej. sparklines de cada categoría).
class ReportsController extends GetxController {}
