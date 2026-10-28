import '../models/shopping_item.dart';
import 'ocr_service.dart';

enum MatchConfidence { exact, high, ambiguous, none }

class MatchCandidate {
  const MatchCandidate({
    required this.item,
    required this.score,
  });

  final ShoppingItem item;
  final double score;
}

class ProductMatchResult {
  const ProductMatchResult({
    required this.confidence,
    required this.candidates,
    this.suggestedPriceCents,
  });

  final MatchConfidence confidence;
  final List<MatchCandidate> candidates;
  final int? suggestedPriceCents;

  ShoppingItem? get bestItem => candidates.isNotEmpty ? candidates.first.item : null;
}

class ProductMatcher {
  ProductMatcher._();

  /// Normaliza texto removendo acentos, pontuação e convertendo para minúsculas
  static String normalize(String text) {
    if (text.isEmpty) return '';
    var s = text.toLowerCase();
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to =   'aaaaaeeeeiiiiooooouuuucn';
    for (var i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }
    return s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Calcula a pontuação de relevância (0.0 a 1.0) entre o texto lido pelo OCR e o item
  static double scoreItem(String ocrName, String ocrFullText, String itemName) {
    final normItem = normalize(itemName);
    if (normItem.isEmpty) return 0.0;

    final itemWords = normItem.split(' ').where((w) => w.length > 1).toSet();
    final effectiveItemWords = itemWords.isEmpty ? normItem.split(' ').toSet() : itemWords;

    double maxScore = 0.0;

    for (final target in [ocrName, ocrFullText]) {
      final normTarget = normalize(target);
      if (normTarget.isEmpty) continue;

      if (normItem == normTarget) {
        return 1.0;
      }

      final targetWords = normTarget.split(' ').toSet();

      // Todas as palavras do item estão no texto detectado
      if (effectiveItemWords.isNotEmpty && effectiveItemWords.every(targetWords.contains)) {
        final lenRatio = normItem.length / normTarget.length;
        final s = 0.82 + 0.18 * lenRatio.clamp(0.0, 1.0);
        if (s > maxScore) maxScore = s;
      }

      // Proporção de palavras em comum
      final common = effectiveItemWords.intersection(targetWords);
      if (common.isNotEmpty && effectiveItemWords.isNotEmpty) {
        final recall = common.length / effectiveItemWords.length;
        final precision = common.length / targetWords.length;
        final s = 0.65 * recall + 0.25 * precision;
        if (s > maxScore) maxScore = s;
      }

      // Substring direta
      if (normTarget.contains(normItem) || normItem.contains(normTarget)) {
        const s = 0.80;
        if (s > maxScore) maxScore = s;
      }
    }

    return maxScore;
  }

  /// Compara o resultado do OCR contra a lista de compras
  static ProductMatchResult match(OcrSuggestion suggestion, List<ShoppingItem> items) {
    final ocrName = suggestion.productName ?? '';
    final ocrText = suggestion.text;

    final candidates = <MatchCandidate>[];

    for (final item in items) {
      if (item.replacedBy != null) continue;
      final score = scoreItem(ocrName, ocrText, item.name);
      if (score >= 0.35) {
        candidates.add(MatchCandidate(item: item, score: score));
      }
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));

    if (candidates.isEmpty) {
      return ProductMatchResult(
        confidence: MatchConfidence.none,
        candidates: const [],
        suggestedPriceCents: suggestion.priceCents,
      );
    }

    final top = candidates.first;

    // Detecta ambiguidade quando os dois primeiros têm pontuações próximas
    if (candidates.length > 1) {
      final second = candidates[1];
      if ((top.score - second.score).abs() < 0.20 && second.score >= 0.40) {
        final ambiguousList = candidates.where((c) => (top.score - c.score) < 0.25).toList();
        return ProductMatchResult(
          confidence: MatchConfidence.ambiguous,
          candidates: ambiguousList,
          suggestedPriceCents: suggestion.priceCents,
        );
      }
    }

    if (top.score >= 0.70) {
      return ProductMatchResult(
        confidence: top.score >= 0.95 ? MatchConfidence.exact : MatchConfidence.high,
        candidates: [top],
        suggestedPriceCents: suggestion.priceCents,
      );
    }

    return ProductMatchResult(
      confidence: MatchConfidence.ambiguous,
      candidates: candidates.take(3).toList(),
      suggestedPriceCents: suggestion.priceCents,
    );
  }
}
