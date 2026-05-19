import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'expense_ocr_data_source.dart';

/// Apple Vision Framework OCR implementation (iOS only, on-device).
/// Uses VNRecognizeTextRequest via platform channel.
class AppleVisionOcrDataSource implements ExpenseOcrDataSource {
  static const _channel = MethodChannel('expense_tracker/ocr');

  @override
  Future<OcrResult?> scan(String imagePath) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'recognizeText',
        {'imagePath': imagePath},
      );

      if (result == null) return null;

      final raw = result['text'] as String? ?? '';
      if (raw.isEmpty) return null;

      final amount = _extractAmount(raw);
      final merchant = result['merchant'] as String?;

      return OcrResult(
        rawText: raw,
        amount: amount,
        merchant: merchant,
      );
    } on PlatformException catch (e) {
      debugPrint('[AppleVision OCR] Error: $e');
      return null;
    }
  }

  String? _extractAmount(String text) {
    final patterns = [
      RegExp(r'[¥￥]?\s*(\d+\.?\d*)'),
      RegExp(r'(?:total|总计|合计|金额|总额)[:\s]*[¥￥]?\s*(\d+\.?\d*)',
          caseSensitive: false),
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
}
