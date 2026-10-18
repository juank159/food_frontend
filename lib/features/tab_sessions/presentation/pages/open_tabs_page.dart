// lib/features/tab_sessions/presentation/pages/open_tabs_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../controllers/open_tabs_controller.dart';
import '../widgets/open_tabs_view.dart';

/// Vista de cuentas abiertas — el "estado del negocio en vivo".
///
/// El cuerpo (stats + lista + "Abrir cuenta libre") vive en
/// `OpenTabsView`, compartido con el segmento "Cuentas abiertas" embebido
/// en la pantalla de Órdenes — UNA sola implementación, dos lugares.
///
/// Bug real reportado: `OpenTabsController` es un singleton global
/// (`Get.lazyPut` en `HomeBinding`/`OpenTabsBinding`) que vive toda la
/// sesión de la app — su `onInit()` (que llama a `load()`) solo corre
/// UNA vez, la primera vez que algo lo toca (ej. el badge de la
/// pantalla de Órdenes). Como esta página antes era un `GetView`
/// (stateless, sin hook propio de "entré a la pantalla"), entrar aquí
/// NO pedía datos frescos — se veía lo que había la primera vez que se
/// creó el controller, hasta que el operario apretaba el botón de
/// refrescar a mano. Esto se sentía como "lentitud" (una cuenta recién
/// creada no aparecía) cuando en realidad nunca se estaba pidiendo de
/// nuevo. Ahora, al entrar a esta pantalla, se pide refresco siempre
/// (sigue siendo local-first: `load()` pinta la caché ya cargada al
/// instante y la red actualiza atrás, sin pantalla en blanco).
class OpenTabsPage extends StatefulWidget {
  const OpenTabsPage({super.key});

  @override
  State<OpenTabsPage> createState() => _OpenTabsPageState();
}

class _OpenTabsPageState extends State<OpenTabsPage> {
  OpenTabsController get controller => Get.find<OpenTabsController>();

  @override
  void initState() {
    super.initState();
    controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            const Expanded(child: OpenTabsView()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return AppGradientHeader(
      title: 'Cuentas abiertas',
      subtitle: 'Mesas y deliveries activos en este momento',
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
      ),
      trailing: GestureDetector(
        onTap: controller.load,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.refresh, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
