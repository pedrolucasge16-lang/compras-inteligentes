import 'package:compras_inteligentes/services/price_parser.dart';
import 'package:flutter_test/flutter_test.dart';

OcrSuggestion read(List<String> lines, {List<double>? heights}) {
  return analyzeLines([
    for (var i = 0; i < lines.length; i++)
      OcrLine(lines[i], heights == null ? 0 : heights[i]),
  ]);
}

void main() {
  group('foto de caderno: CAFE 16,00', () {
    test('lê nome e preço na mesma linha', () {
      final r = read(['CAFE 16,00']);
      expect(r.productName, 'Café');
      expect(r.priceCents, 1600);
      expect(r.ambiguous, isFalse);
    });

    test('aceita 0 lido como letra Q ou O', () {
      expect(read(['CAFE 16,0Q']).priceCents, 1600);
      expect(read(['CAFE 16,OO']).priceCents, 1600);
    });

    test('aceita ponto, vírgula dupla e espaços', () {
      expect(read(['CAFE 16.00']).priceCents, 1600);
      expect(read(['CAFE 16,,00']).priceCents, 1600);
      expect(read(['CAFE 16 , 00']).priceCents, 1600);
    });

    test('o nome nunca fica com o preço junto', () {
      expect(read(['CAFE 16,00']).productName, isNot(contains('16')));
    });
  });

  group('formatos brasileiros', () {
    test('R\$ 16,00 e R\$16,00', () {
      expect(read(['R\$ 16,00']).priceCents, 1600);
      expect(read(['R\$16,00']).priceCents, 1600);
    });

    test('milhar com ponto', () {
      expect(read(['R\$ 1.234,56']).priceCents, 123456);
    });

    test('R\$ sem centavos', () {
      expect(read(['Café', 'R\$ 16']).priceCents, 1600);
    });
  });

  group('não confunde com outros números', () {
    test('ignora código de barras, peso e validade', () {
      final r = read([
        'Café Tradicional',
        '7891000100103',
        'Peso líquido 500 g',
        'Val 27.10.26',
        'R\$ 16,00',
      ]);
      expect(r.priceCents, 1600);
      expect(r.candidates, [1600]);
      expect(r.productName, 'Café Tradicional');
    });

    test('ignora volume com vírgula (1,50 L)', () {
      final r = read(['Suco 1,50 L', 'R\$ 8,99']);
      expect(r.priceCents, 899);
      expect(r.candidates, [899]);
    });

    test('ignora tabela nutricional', () {
      final r = read([
        'Valor energético 120 kcal',
        'Carboidratos 12,00 g',
        'Café 16,00',
      ]);
      expect(r.priceCents, 1600);
    });

    test('ignora valor zero', () {
      expect(read(['Café 0,00']).priceCents, isNull);
    });
  });

  group('vários preços e ausência de preço', () {
    test('dois preços parecidos pedem revisão', () {
      final r = read(['Café 16,00', 'Café forte 18,50']);
      expect(r.ambiguous, isTrue);
      expect(r.candidates.length, 2);
      expect(r.candidates, containsAll([1600, 1850]));
    });

    test('R\$ pesa mais que número solto', () {
      final r = read(['Oferta 12,00', 'R\$ 10,00']);
      expect(r.priceCents, 1000);
      expect(r.ambiguous, isFalse);
    });

    test('texto grande ganha desempate', () {
      final r = read(['Café 18,50', 'R\$ 16,00'], heights: [20, 80]);
      expect(r.priceCents, 1600);
      expect(r.ambiguous, isFalse);
    });

    test('sem preço: devolve só o nome', () {
      final r = read(['Café Tradicional']);
      expect(r.priceCents, isNull);
      expect(r.candidates, isEmpty);
      expect(r.productName, 'Café Tradicional');
    });

    test('sem texto', () {
      final r = read([]);
      expect(r.priceCents, isNull);
      expect(r.productName, isNull);
    });
  });
}
