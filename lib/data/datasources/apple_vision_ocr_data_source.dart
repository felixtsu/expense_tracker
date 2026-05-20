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

      debugPrint('[OCR Raw] $raw');
      final nativeCandidates = result['amountCandidates'] as List<dynamic>?;
      final amountCandidates = parseAmountCandidates(raw, nativeCandidates);
      final merchant = result['merchant'] as String?;
      debugPrint(
        '[OCR Result] candidates=${amountCandidates.length} merchant=$merchant',
      );

      if (amountCandidates.isEmpty) return null;

      return OcrResult(
        rawText: raw,
        amountCandidates: amountCandidates,
        merchant: merchant,
      );
    } on PlatformException catch (e) {
      debugPrint('[AppleVision OCR] Error: $e');
      return null;
    }
  }
}
