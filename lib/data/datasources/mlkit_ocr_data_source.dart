import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'expense_ocr_data_source.dart';

/// ML Kit-based OCR implementation (iOS + Android, on-device).
class MlKitOcrDataSource implements ExpenseOcrDataSource {
  MlKitOcrDataSource() : _recognizer = TextRecognizer();

  final TextRecognizer _recognizer;

  @override
  Future<OcrResult?> scan(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await _recognizer.processImage(inputImage);

      if (recognized.text.isEmpty) return null;

      final raw = recognized.text;
      final amount = _extractAmount(raw);
      final merchant = _extractMerchant(recognized);

      return OcrResult(
        rawText: raw,
        amount: amount,
        merchant: merchant,
      );
    } catch (e) {
      debugPrint('[MLKit OCR] Error: $e');
      return null;
    }
  }

  /// Pull the first textual block that looks like a total / amount.
  String? _extractAmount(String text) {
    // Look for patterns like: ¥25.50  25.50  RMB 25.50  总计 128.00
    final patterns = [
      RegExp(r'[¥￥]?\s*(\d+\.?\d*)'),          // ¥128 or 128.00
      RegExp(r'[¥￥]?\s*(\d{1,6}\.?\d{0,2})'), // general
      RegExp(r'(?:total|总计|合计|金额)[:\s]*[¥￥]?\s*(\d+\.?\d*)', caseSensitive: false),
    ];

    double? best;
    for (final p in patterns) {
      for (final m in p.allMatches(text)) {
        final v = double.tryParse(m.group(1) ?? '');
        if (v != null && v > 0) {
          if (best == null || v > best) best = v;
        }
      }
    }

    return best?.toStringAsFixed(2);
  }

  /// Use the first large text block as the likely merchant name.
  String? _extractMerchant(RecognizedText recognized) {
    // Heuristic: the merchant name is usually one of the first few lines,
    // and tends to be longer than a single short word.
    for (final block in recognized.blocks) {
      final text = block.text.trim();
      if (text.length >= 4) return text;
    }
    return null;
  }
}
