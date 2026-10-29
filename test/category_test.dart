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

  test('identifica automaticamente a categoria pelo nome do produto', () {
    expect(ProductCategory.detectCategory('Frango'), 'Carnes');
    expect(ProductCategory.detectCategory('Peito de frango'), 'Carnes');
    expect(ProductCategory.detectCategory('Picanha'), 'Carnes');
    expect(ProductCategory.detectCategory('Sabão em pó'), 'Limpeza');
    expect(ProductCategory.detectCategory('Detergente'), 'Limpeza');
    expect(ProductCategory.detectCategory('Leite integral'), 'Laticínios');
    expect(ProductCategory.detectCategory('Arroz'), 'Cereais');
    expect(ProductCategory.detectCategory('Banana'), 'Frutas e verduras');
    expect(ProductCategory.detectCategory('Macarrão espaguete'), 'Massas');
    expect(ProductCategory.detectCategory('Papel higiênico'), 'Higiene pessoal');
  });

  test('permite ao usuário cadastrar novos itens personalizados no banco de setores', () {
    ProductCategory.setCustomKeywords({});
    expect(ProductCategory.detectCategory('Kefir artesanal'), 'Outros');

    ProductCategory.addCustomKeyword('Laticínios', 'Kefir');
    expect(ProductCategory.detectCategory('Kefir artesanal'), 'Laticínios');
    expect(ProductCategory.detectCategory('kefir'), 'Laticínios');

    ProductCategory.removeCustomKeyword('Laticínios', 'Kefir');
    expect(ProductCategory.detectCategory('Kefir artesanal'), 'Outros');
  });

  test('retorna ícones e cores para cada categoria sem erro', () {
    for (final cat in ProductCategory.all) {
      expect(ProductCategory.iconFor(cat), isNotNull);
      expect(ProductCategory.colorFor(cat), isNotNull);
    }
    expect(ProductCategory.iconFor('Desconhecida'), isNotNull);
    expect(ProductCategory.colorFor('Desconhecida'), isNotNull);
  });
}
