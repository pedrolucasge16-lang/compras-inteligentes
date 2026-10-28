import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'price_parser.dart';

export 'price_parser.dart' show OcrSuggestion;

class OcrService {
  /// Lê a foto e sugere nome e preço. A interpretação do texto fica em
  /// `price_parser.dart` (testável sem celular).
  static Future<OcrSuggestion> readImage(String path) async {
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      throw StateError('A foto não foi encontrada ou está vazia. Tire a foto de novo.');
    }
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(path));
      final lines = <OcrLine>[];
      for (final block in result.blocks) {
        for (final line in block.lines) {
          final text = line.text.trim();
          if (text.isNotEmpty) lines.add(OcrLine(text, line.boundingBox.height));
        }
      }
      if (lines.isEmpty) {
        for (final text in result.text.split('\n')) {
          if (text.trim().isNotEmpty) lines.add(OcrLine(text.trim()));
        }
      }
      return analyzeLines(lines);
    } finally {
      await recognizer.close();
    }
  }
}
