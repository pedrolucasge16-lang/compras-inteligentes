import 'package:compras_inteligentes/models/shopping_item.dart';
import 'package:compras_inteligentes/services/quantity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('+ aumenta de 1 em 1 para unidade', () {
    expect(nextQuantity(1, 'un', 1), 2);
  });

  test('− nunca chega a zero', () {
    expect(nextQuantity(1, 'un', -1), isNull);
    expect(nextQuantity(2, 'un', -1), 1);
  });

  test('kg e L andam de meio em meio', () {
    expect(nextQuantity(1, 'kg', 1), 1.5);
    expect(nextQuantity(0.5, 'kg', -1), isNull);
    expect(nextQuantity(1.5, 'L', -1), 1);
  });

  test('g e ml andam de 100 em 100', () {
    expect(nextQuantity(500, 'g', 1), 600);
    expect(nextQuantity(100, 'ml', -1), isNull);
  });

  test('formatQuantity não mostra .0', () {
    expect(formatQuantity(2), '2');
    expect(formatQuantity(0.5), '0,5');
    expect(formatQuantity(1.5), '1,5');
  });

  test('subtotal acompanha a quantidade (café 2 x R\$ 16,00 = R\$ 32,00)', () {
    const item = ShoppingItem(
      name: 'Café',
      quantity: 1,
      unit: 'un',
      unitPriceCents: 1600,
    );
    expect(item.subtotalCents, 1600);
    final dois = item.copyWith(quantity: nextQuantity(1, 'un', 1));
    expect(dois.subtotalCents, 3200);
  });

  test('subtotal usa o preço real pago ao mudar a quantidade', () {
    const item = ShoppingItem(
      name: 'Café',
      quantity: 1,
      unit: 'un',
      unitPriceCents: 1600,
      isBought: true,
      actualUnitPriceCents: 1500,
    );
    final tres = item.copyWith(quantity: 3);
    expect(tres.subtotalCents, 4500);
    expect(tres.isBought, isTrue);
    expect(tres.actualUnitPriceCents, 1500);
  });
}
