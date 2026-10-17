import 'package:flutter_test/flutter_test.dart';
import 'package:menu_plat/core/services/offline_queue_service.dart';

void main() {
  group('remapIdsDeep — resuelve ids locales a ids reales en la cola', () {
    test('reemplaza un id local que es el valor exacto de un campo', () {
      final idMap = {'local_cat_123': 'real-cat-abc'};
      final body = {'name': 'Bebidas', 'category_id': 'local_cat_123'};

      final result = remapIdsDeep(body, idMap);

      expect(result['category_id'], 'real-cat-abc');
      expect(result['name'], 'Bebidas');
    });

    test('reemplaza un id local embebido DENTRO de un path ya armado', () {
      // Caso real: `addModifiersToGroup` arma el path con el groupId
      // ya interpolado (`/products/modifier-groups/<id>/modifiers`).
      // Si ese id es local, el reemplazo tiene que encontrarlo aunque
      // no sea el string completo.
      final idMap = {'local_mg_123': 'real-group-id'};
      final payload = {
        'method': 'POST',
        'path': '/products/modifier-groups/local_mg_123/modifiers',
        'body': {'modifier_ids': <String>[]},
      };

      final result = remapIdsDeep(payload, idMap);

      expect(result['path'], '/products/modifier-groups/real-group-id/modifiers');
    });

    test('reemplaza ids locales dentro de una lista (ej. flavor_ids)', () {
      final idMap = {
        'local_flavor_1': 'real-flavor-1',
        'local_flavor_2': 'real-flavor-2',
      };
      final body = {
        'flavor_ids': ['local_flavor_1', 'real-flavor-already-synced', 'local_flavor_2'],
      };

      final result = remapIdsDeep(body, idMap);

      expect(result['flavor_ids'], [
        'real-flavor-1',
        'real-flavor-already-synced',
        'real-flavor-2',
      ]);
    });

    test('no toca nada si no hay ningún id local en el idMap presente', () {
      final idMap = {'local_prod_999': 'real-prod-999'};
      final body = {'name': 'Hamburguesa', 'category_id': 'real-cat-ya-sincronizada'};

      final result = remapIdsDeep(body, idMap);

      expect(result, body);
    });

    test('idMap vacío devuelve el nodo intacto', () {
      final body = {'category_id': 'local_cat_1'};
      expect(remapIdsDeep(body, {}), body);
    });

    test('resuelve recursivamente dentro de mapas anidados', () {
      final idMap = {'local_prod_1': 'real-prod-1'};
      final payload = {
        'body': {
          'nested': {'product_id': 'local_prod_1'},
        },
      };

      final result = remapIdsDeep(payload, idMap);

      expect(result['body']['nested']['product_id'], 'real-prod-1');
    });
  });
}
