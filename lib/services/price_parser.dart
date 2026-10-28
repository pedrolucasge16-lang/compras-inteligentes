/// Interpretação do texto lido pelo OCR. Este arquivo NÃO usa ML Kit
/// nem Flutter, para poder ser testado sem celular.
library;

class OcrLine {
  const OcrLine(this.text, [this.height = 0]);
  final String text;

  /// Altura da linha na foto (texto grande costuma ser o preço de destaque).
  final double height;
}

class OcrSuggestion {
  const OcrSuggestion({
    required this.text,
    this.productName,
    this.priceCents,
    this.candidates = const [],
    this.ambiguous = false,
  });

  /// Texto bruto lido da imagem.
  final String text;
  final String? productName;
  final int? priceCents;

  /// Todos os preços plausíveis, do mais provável para o menos provável.
  final List<int> candidates;

  /// Verdadeiro quando há mais de um preço plausível e o usuário deve escolher.
  final bool ambiguous;
}

class _Match {
  _Match(this.cents, this.start, this.end, this.score, this.lineIndex);
  final int cents;
  final int start;
  final int end;
  int score;
  final int lineIndex;
}

// Centavos aceitam O/Q/D no lugar de 0 (letra mal lida em foto ruim).
final _pricePattern = RegExp(
  r'(R\s?\$\s?)?(\d{1,3}(?:\.\d{3})+|\d{1,6})\s?[,.]{1,2}\s?([0-9OoQqDd]{2})(?![0-9A-Za-z])',
);
final _rsIntegerPattern = RegExp(r'R\s?\$\s?(\d{1,4})(?![0-9.,])');
final _measureAfter = RegExp(
  r'^\s*(kg|g|gr|mg|ml|l|lt|litros?|un|und|%)(?![A-Za-z])',
  caseSensitive: false,
);
final _noiseLine = RegExp(
  r'kcal|\bkj\b|valor energ|carboidrat|prote[ií]na|gordura|s[oó]dio|fibra|\bvd\b|'
  r'validade|\bval\b|\bfab\b|fabrica|\blote\b|venc|\bsac\b|www\.|\.com|cnpj|ind[uú]stria|'
  r'conte[uú]do|peso l[ií]q|\bnet\b',
  caseSensitive: false,
);
final _longDigits = RegExp(r'\d{8,}');
final _date = RegExp(r'\d{1,2}[./-]\d{1,2}[./-]\d{2,4}');

const _accents = {
  'cafe': 'Café',
  'acucar': 'Açúcar',
  'feijao': 'Feijão',
  'macarrao': 'Macarrão',
  'oleo': 'Óleo',
  'agua': 'Água',
  'sabao': 'Sabão',
  'po': 'Pó',
  'maca': 'Maçã',
  'limao': 'Limão',
  'pao': 'Pão',
  'cha': 'Chá',
  'guarana': 'Guaraná',
  'requeijao': 'Requeijão',
};

int _toCents(String whole, String cents) {
  final w = int.parse(whole.replaceAll('.', ''));
  final c = int.parse(cents.replaceAll(RegExp(r'[OoQqDd]'), '0'));
  return w * 100 + c;
}

List<_Match> _findPrices(String line, int lineIndex) {
  final found = <_Match>[];
  for (final m in _pricePattern.allMatches(line)) {
    final hasRs = m.group(1) != null;
    final before = m.start > 0 ? line[m.start - 1] : '';
    final after = line.substring(m.end);
    // Faz parte de um número maior (ex.: 123456,78 colado em outro dígito).
    if (!hasRs && RegExp(r'\d').hasMatch(before)) continue;
    // Continua como data ou versão (ex.: 27.10.26).
    if (RegExp(r'^[.,]\d').hasMatch(after)) continue;
    // Peso ou volume (ex.: 1,50 L), exceto quando há R$ na frente.
    if (!hasRs && _measureAfter.hasMatch(after)) continue;
    final cents = _toCents(m.group(2)!, m.group(3)!);
    if (cents <= 0) continue;
    found.add(_Match(cents, m.start, m.end, hasRs ? 4 : 1, lineIndex));
  }
  // "R$ 16" sem centavos: aceito, com pontuação menor.
  for (final m in _rsIntegerPattern.allMatches(line)) {
    final overlaps = found.any((f) => m.start < f.end && m.end > f.start);
    if (overlaps) continue;
    final cents = int.parse(m.group(1)!) * 100;
    if (cents > 0) found.add(_Match(cents, m.start, m.end, 2, lineIndex));
  }
  return found;
}

String _capitalize(String s) {
  final lower = s.toLowerCase();
  final fixed = _accents[lower];
  if (fixed != null) return fixed;
  if (lower.isEmpty) return lower;
  return lower[0].toUpperCase() + lower.substring(1);
}

/// Limpa um trecho de texto para virar nome de produto.
String? _cleanName(String raw) {
  var s = raw.replaceAll(RegExp(r'R\s?\$'), ' ');
  s = s.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ\s\-]'), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  final words = s.split(' ').where((w) => w.length > 1 || w == 'e').toList();
  if (words.isEmpty) return null;
  s = words.join(' ');
  final letters = RegExp(r'[A-Za-zÀ-ÿ]').allMatches(s).length;
  if (letters < 3) return null;
  final allCaps = s == s.toUpperCase();
  if (allCaps || s == s.toLowerCase()) {
    return s.split(' ').map(_capitalize).join(' ');
  }
  return s;
}

/// Analisa as linhas do OCR e sugere nome e preço.
/// Nunca assume que o primeiro número é o preço.
OcrSuggestion analyzeLines(List<OcrLine> lines) {
  final raw = lines.map((l) => l.text).join('\n');
  final heights = lines.map((l) => l.height).where((h) => h > 0).toList()
    ..sort();
  final median = heights.isEmpty ? 0.0 : heights[heights.length ~/ 2];

  final matches = <_Match>[];
  for (var i = 0; i < lines.length; i++) {
    final text = lines[i].text;
    if (_noiseLine.hasMatch(text) || _longDigits.hasMatch(text)) continue;
    if (_date.hasMatch(text)) continue;
    final found = _findPrices(text, i);
    for (final m in found) {
      if (median > 0 && lines[i].height >= median * 1.3) m.score += 2;
      matches.add(m);
    }
  }

  // Mesmo valor em mais de um lugar conta uma vez só (mantém a maior pontuação).
  final best = <int, _Match>{};
  for (final m in matches) {
    final old = best[m.cents];
    if (old == null || m.score > old.score) best[m.cents] = m;
  }
  final ranked = best.values.toList()
    ..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return lines[b.lineIndex].height.compareTo(lines[a.lineIndex].height);
    });

  final candidates = ranked.map((m) => m.cents).toList();
  final chosen = ranked.isEmpty ? null : ranked.first;
  final ambiguous = ranked.length > 1 && ranked[0].score - ranked[1].score < 2;

  // Nome: primeiro tenta o texto da mesma linha do preço escolhido.
  String? name;
  if (chosen != null) {
    final line = lines[chosen.lineIndex].text;
    final without = line.replaceRange(chosen.start, chosen.end, ' ');
    name = _cleanName(without);
  }
  if (name == null) {
    final options = <MapEntry<String, double>>[];
    for (final l in lines) {
      if (_noiseLine.hasMatch(l.text) || _longDigits.hasMatch(l.text)) continue;
      final cleaned = _cleanName(l.text);
      if (cleaned != null) options.add(MapEntry(cleaned, l.height));
    }
    if (options.isNotEmpty) {
      // Linha mais alta; em empate, a primeira que apareceu.
      var top = options.first;
      for (final o in options.skip(1)) {
        if (o.value > top.value) top = o;
      }
      name = top.key;
    }
  }

  return OcrSuggestion(
    text: raw,
    productName: name,
    priceCents: chosen?.cents,
    candidates: candidates,
    ambiguous: ambiguous,
  );
}
