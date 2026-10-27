import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ResultadoLeitura {
  final List<int> precos; // centavos, do mais destacado para o menos
  final List<String> textos; // linhas que podem ser o nome do produto
  final bool houveTexto;

  const ResultadoLeitura({
    required this.precos,
    required this.textos,
    required this.houveTexto,
  });
}

final _padraoPreco =
    RegExp(r'(\d{1,3}(?:\.\d{3})+|\d{1,6})\s?[,.]\s?(\d{2})(?!\d)');
final _padraoMedida =
    RegExp(r'^\s*(kg|g|gr|mg|ml|l|lt)\b', caseSensitive: false);
final _padraoDigito = RegExp(r'\d');
final _padraoContinua = RegExp(r'^[.,]\d');

/// Procura valores como 12,99 ou 1.234,50 dentro de uma linha de texto.
List<int> extrairPrecos(String linha) {
  final achados = <int>[];
  for (final m in _padraoPreco.allMatches(linha)) {
    final antes = m.start > 0 ? linha[m.start - 1] : '';
    final depois = linha.substring(m.end);
    if (_padraoDigito.hasMatch(antes)) continue; // parte de número maior
    if (_padraoContinua.hasMatch(depois)) continue; // ex.: data 27.10.26
    if (_padraoMedida.hasMatch(depois)) continue; // ex.: 1,50 L ou 0,75 kg
    final reais = int.parse(m.group(1)!.replaceAll('.', ''));
    final cent = int.parse(m.group(2)!);
    final total = reais * 100 + cent;
    if (total > 0) achados.add(total);
  }
  return achados;
}

bool _pareceNome(String t) {
  final letras = RegExp(r'[A-Za-zÀ-ÿ]').allMatches(t).length;
  return t.length >= 3 && letras >= 3 && letras * 2 >= t.length;
}

class _Achado {
  final int centavos;
  final double altura;
  const _Achado(this.centavos, this.altura);
}

class LeitorEtiqueta {
  final TextRecognizer _reconhecedor =
      TextRecognizer(script: TextRecognitionScript.latin);

  Future<ResultadoLeitura> ler(String caminhoImagem) async {
    final imagem = InputImage.fromFilePath(caminhoImagem);
    final texto = await _reconhecedor.processImage(imagem);

    final achados = <_Achado>[];
    final textos = <String>[];

    for (final bloco in texto.blocks) {
      for (final linha in bloco.lines) {
        final conteudo = linha.text.trim();
        if (conteudo.isEmpty) continue;
        final precos = extrairPrecos(conteudo);
        for (final p in precos) {
          achados.add(_Achado(p, linha.boundingBox.height));
        }
        final semPreco = precos.isEmpty
            ? conteudo
            : conteudo
                .replaceAll(_padraoPreco, ' ')
                .replaceAll('R\$', ' ')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
        if (_pareceNome(semPreco)) textos.add(semPreco);
      }
    }

    achados.sort((a, b) => b.altura.compareTo(a.altura));
    final vistos = <int>{};
    final precos = <int>[];
    for (final a in achados) {
      if (vistos.add(a.centavos)) precos.add(a.centavos);
    }

    return ResultadoLeitura(
      precos: precos,
      textos: textos.take(8).toList(),
      houveTexto: texto.text.trim().isNotEmpty,
    );
  }

  Future<void> fechar() => _reconhecedor.close();
}
