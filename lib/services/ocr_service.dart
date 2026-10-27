import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrSuggestion {
  const OcrSuggestion({required this.text, this.productName, this.priceCents});
  final String text;
  final String? productName;
  final int? priceCents;
}

class OcrService {
  static Future<OcrSuggestion> readImage(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(path));
      final text = result.text;
      // Accepts examples such as 8,99, R$ 8.99 and 1.234,56.
      final priceMatch = RegExp(r'(?:R\$\s*)?(\d{1,3}(?:\.\d{3})*|\d+)[,.](\d{2})\b').firstMatch(text);
      int? cents;
      if (priceMatch != null) {
        final whole = priceMatch.group(1)!.replaceAll('.', '');
        cents = int.parse(whole) * 100 + int.parse(priceMatch.group(2)!);
      }
      final lines = text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final nameCandidates = lines.where((line) =>
        !RegExp(r'R\$|\d+[,.]\d{2}').hasMatch(line) &&
        !RegExp(r'^\d+$').hasMatch(line) && line.length > 2).toList();
      final name = nameCandidates.isEmpty ? null : nameCandidates.first;
      return OcrSuggestion(text: text, productName: name, priceCents: cents);
    } finally {
      await recognizer.close();
    }
  }
}
