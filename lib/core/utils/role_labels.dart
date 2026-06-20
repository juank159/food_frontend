/// Etiquetas de rol en ESPAÑOL para mostrar al usuario.
///
/// El backend siembra los roles con nombre en inglés (Administrator, Manager,
/// Cashier, Waiter, Kitchen Staff, Delivery Person, Bartender) pero los
/// usuarios finales (meseros, cajeros) no saben inglés. Mapeamos por el
/// `code` del rol (estable) a una etiqueta en español, sin depender de lo
/// que tenga guardado el `name` en la base de cada tenant.
///
/// Para roles personalizados (códigos desconocidos) cae al `fallback`
/// (normalmente el `name` que cargó el admin).
const Map<String, String> kRoleLabelsEs = {
  'admin': 'Administrador',
  'manager': 'Gerente',
  'cashier': 'Cajero',
  'waiter': 'Mesero',
  'kitchen': 'Cocina',
  'delivery': 'Domiciliario',
  'bartender': 'Bartender',
};

/// Devuelve el nombre del rol en español a partir de su `code`.
/// Si el code no está mapeado (rol personalizado), usa `fallback` (el nombre
/// guardado) y si tampoco hay, "Sin rol".
String roleLabelEs(String? code, {String? fallback}) {
  final c = (code ?? '').trim().toLowerCase();
  if (kRoleLabelsEs.containsKey(c)) return kRoleLabelsEs[c]!;
  final fb = fallback?.trim();
  if (fb != null && fb.isNotEmpty) return fb;
  return 'Sin rol';
}
