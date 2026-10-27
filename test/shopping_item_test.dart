import 'package:flutter_test/flutter_test.dart';
import 'package:compras_inteligentes/models/shopping_item.dart';

void main() {
  test('subtotal usa o preço real quando ele foi confirmado', () {
    const item = ShoppingItem(
      name: 'Arroz', quantity: 2, unit: 'un', unitPriceCents: 2500,
      isBought: true, actualUnitPriceCents: 2299,
    );
    expect(item.subtotalCents, 4598);
  });

  test('item substituído mantém referência e nome original', () {
    const item = ShoppingItem(
      id: 8, name: 'Leite semidesnatado', quantity: 1, unit: 'L',
      unitPriceCents: 599, originalItemId: 7, originalItemName: 'Leite integral',
    );
    final restored = ShoppingItem.fromMap(item.toMap());
    expect(restored.originalItemId, 7);
    expect(restored.originalItemName, 'Leite integral');
  });
}
