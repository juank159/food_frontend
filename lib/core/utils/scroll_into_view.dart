import 'package:flutter/widgets.dart';

/// Asegura que el campo marcado con [key] quede visible por encima del
/// teclado — para `TextField`s numéricos dentro de diálogos/sheets con
/// scroll propio (monto a cobrar, recibido, etc.).
///
/// **Por qué hace falta esto y no alcanza con el auto-scroll de
/// Flutter:** cuando el teclado numérico se abre en celular, el
/// diálogo recalcula su alto disponible (`MediaQuery.viewInsets.bottom`)
/// en el MISMO frame en que el campo pide foco — el auto-scroll interno
/// de `EditableText` corre ANTES de que ese recálculo termine, así que
/// a veces el campo queda justo debajo del teclado, tapado, sin avisar
/// — el cajero ve el teclado pero no ve lo que está escribiendo.
///
/// Se llama desde `onTap:` del campo. El delay deja que la animación
/// del teclado arranque (el inset ya cambió apenas se abre, pero el
/// layout del diálogo tarda un frame extra en acomodarse) antes de
/// pedir "mostrate" — así el cálculo de scroll usa el tamaño FINAL del
/// contenedor, no el de antes de que apareciera el teclado.
void ensureFieldVisible(GlobalKey key) {
  Future.delayed(const Duration(milliseconds: 280), () {
    final ctx = key.currentContext;
    if (ctx == null) return;
    // El lint de "BuildContext a través de un gap async" no aplica acá:
    // `ctx` se obtiene RECIÉN DESPUÉS del delay (no se guardó uno viejo
    // de antes de esperar), y si el widget ya se desmontó, `currentContext`
    // da null y el `return` de arriba corta antes de usarlo.
    Scrollable.ensureVisible(
      // ignore: use_build_context_synchronously
      ctx,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      // 0.15 en vez de 0.0/0.5: deja el campo cerca de arriba del
      // espacio visible pero con un margen debajo, para que el
      // helperText/contador de cambio que aparece al escribir no quede
      // pegado al borde del teclado.
      alignment: 0.15,
    );
  });
}
