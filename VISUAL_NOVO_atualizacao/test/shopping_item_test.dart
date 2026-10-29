import 'package:compras_inteligentes/models/shopping_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('subtotal usa o preço real quando ele foi confirmado', () {
    const item = ShoppingItem(
      name: 'Arroz',
      quantity: 2,
      unit: 'un',
      unitPriceCents: 2500,
      isBought: true,
      actualUnitPriceCents: 2299,
    );
    expect(item.subtotalCents, 4598);
  });

  test('item substituído mantém referência e nome original', () {
    const item = ShoppingItem(
      id: 8,
      name: 'Leite semidesnatado',
      quantity: 1,
      unit: 'L',
      unitPriceCents: 599,
      originalItemId: 7,
      originalItemName: 'Leite integral',
    );
    final restored = ShoppingItem.fromMap(item.toMap());
    expect(restored.originalItemId, 7);
    expect(restored.originalItemName, 'Leite integral');
  });

  test('suporte a categorias e compras parciais', () {
    const item = ShoppingItem(
      id: 10,
      name: 'Leite Integral',
      quantity: 3,
      unit: 'L',
      unitPriceCents: 500,
      category: 'Laticínios',
      boughtQuantity: 2.0,
      isBought: false,
    );

    expect(item.remainingQuantity, 1.0);
    expect(item.isPartiallyBought, isTrue);
    expect(item.isFullyBought, isFalse);
    expect(item.isPending, isTrue);
    expect(item.boughtSubtotalCents, 1000); // 2 * 500

    final map = item.toMap();
    expect(map['category'], 'Laticínios');
    expect(map['bought_quantity'], 2.0);

    final fromDb = ShoppingItem.fromMap(map);
    expect(fromDb.category, 'Laticínios');
    expect(fromDb.boughtQuantity, 2.0);
    expect(fromDb.remainingQuantity, 1.0);
  });

  test('conclusão total de item atualiza flags corretamente', () {
    const item = ShoppingItem(
      name: 'Café',
      quantity: 2,
      unit: 'un',
      unitPriceCents: 1600,
      boughtQuantity: 2.0,
      isBought: true,
    );

    expect(item.remainingQuantity, 0.0);
    expect(item.isFullyBought, isTrue);
    expect(item.isPartiallyBought, isFalse);
    expect(item.isPending, isFalse);
  });
}
