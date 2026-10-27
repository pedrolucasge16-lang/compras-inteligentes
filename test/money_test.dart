import 'package:flutter_test/flutter_test.dart';
import 'package:compras_inteligentes/services/money.dart';
import 'package:compras_inteligentes/services/price_comparator.dart';

void main() {
  test('converte dinheiro em centavos sem arredondamento binário', () {
    expect(parseMoneyToCents('8,99'), 899);
    expect(parseMoneyToCents('R\$ 1.234,56'), 123456);
    expect(formatCents(899), 'R\$ 8,99');
  });

  test('calcula 2, 5, 10 e 20 unidades', () {
    expect(quantitiesCost(450), [900, 2250, 4500, 9000]);
  });

  test('compara embalagens de massa compatíveis', () {
    final a = PackageOption(name: 'A', amount: 500, unit: 'g', priceCents: 800);
    final b = PackageOption(name: 'B', amount: 1, unit: 'kg', priceCents: 1400);
    expect(areComparable(a, b), isTrue);
    expect(pricePerBaseUnit(b)! < pricePerBaseUnit(a)!, isTrue);
    expect(calculatePackages(a, 1000)!.packages, 2);
  });

  test('não compara massa com volume', () {
    final a = PackageOption(name: 'A', amount: 500, unit: 'g', priceCents: 800);
    final b = PackageOption(name: 'B', amount: 1, unit: 'l', priceCents: 1400);
    expect(areComparable(a, b), isFalse);
  });
}
