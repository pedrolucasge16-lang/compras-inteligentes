import 'package:compras_inteligentes/models/category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('possui exatamente as 11 categorias solicitadas na ordem correta', () {
    expect(ProductCategory.all.length, 11);
    expect(ProductCategory.all, [
      'Carnes',
      'Frutas e verduras',
      'Laticínios',
      'Cereais',
      'Massas',
      'Bebidas',
      'Padaria',
      'Higiene pessoal',
      'Limpeza',
      'Congelados',
      'Outros',
    ]);
  });

  test('retorna ícones e cores para cada categoria sem erro', () {
    for (final cat in ProductCategory.all) {
      expect(ProductCategory.iconFor(cat), isNotNull);
      expect(ProductCategory.colorFor(cat), isNotNull);
    }
    // Categoria desconhecida deve retornar padrão sem crash
    expect(ProductCategory.iconFor('Desconhecida'), isNotNull);
    expect(ProductCategory.colorFor('Desconhecida'), isNotNull);
  });
}
