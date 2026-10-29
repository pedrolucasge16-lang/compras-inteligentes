import 'package:compras_inteligentes/models/shopping_item.dart';
import 'package:compras_inteligentes/services/ocr_service.dart';
import 'package:compras_inteligentes/services/product_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final items = [
    const ShoppingItem(name: 'Café tradicional', quantity: 2, unit: 'un', unitPriceCents: 1600, category: 'Outros'),
    const ShoppingItem(name: 'Café descafeinado', quantity: 1, unit: 'un', unitPriceCents: 1800, category: 'Outros'),
    const ShoppingItem(name: 'Leite integral', quantity: 3, unit: 'L', unitPriceCents: 550, category: 'Laticínios'),
    const ShoppingItem(name: 'Arroz 5kg', quantity: 1, unit: 'un', unitPriceCents: 2600, category: 'Cereais'),
  ];

  test('reconhecimento de correspondência exata ou de alta confiança', () {
    const suggestion = OcrSuggestion(
      text: 'LEITE INTEGRAL 1L',
      productName: 'Leite integral',
      priceCents: 549,
      candidates: [549],
      ambiguous: false,
    );

    final result = ProductMatcher.match(suggestion, items);
    expect(result.confidence, anyOf(MatchConfidence.exact, MatchConfidence.high));
    expect(result.bestItem?.name, 'Leite integral');
    expect(result.suggestedPriceCents, 549);
  });

  test('reconhecimento de ambiguidade com múltiplos produtos semelhantes', () {
    const suggestion = OcrSuggestion(
      text: 'CAFE PILAO',
      productName: 'Café',
      priceCents: 1600,
      candidates: [1600],
      ambiguous: false,
    );

    final result = ProductMatcher.match(suggestion, items);
    expect(result.confidence, MatchConfidence.ambiguous);
    expect(result.candidates.length, greaterThanOrEqualTo(2));
    final names = result.candidates.map((c) => c.item.name).toList();
    expect(names, containsAll(['Café tradicional', 'Café descafeinado']));
  });

  test('produto não cadastrado na lista resulta em none', () {
    const suggestion = OcrSuggestion(
      text: 'DETERGENTE YPE 500ML',
      productName: 'Detergente Ypê',
      priceCents: 239,
      candidates: [239],
      ambiguous: false,
    );

    final result = ProductMatcher.match(suggestion, items);
    expect(result.confidence, MatchConfidence.none);
    expect(result.candidates, isEmpty);
    expect(result.suggestedPriceCents, 239);
  });
}
