import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'expense_ocr_data_source.dart';
import 'apple_vision_ocr_data_source.dart';

export 'expense_ocr_data_source.dart'
    show AmountCandidate, OcrResult, ExpenseOcrDataSource;

/// Factory that returns the best available OCR implementation for the current platform.
///
/// - Android → Google ML Kit (via platform channel, in native Kotlin)
/// - iOS      → Apple Vision Framework (via platform channel, in native Swift)
ExpenseOcrDataSource createOcrDataSource() {
  if (Platform.isAndroid) {
    return _AndroidMlKitOcr();
  } else if (Platform.isIOS) {
    return AppleVisionOcrDataSource();
  } else {
    // Desktop, web, and `flutter test` VM — OCR unavailable; scan() returns null.
    return _StubOcrDataSource();
  }
}

/// No-op OCR for platforms without native recognizers (tests, macOS, web).
class _StubOcrDataSource implements ExpenseOcrDataSource {
  @override
  Future<OcrResult?> scan(String imagePath) async => null;
}

/// Android: delegates to native Kotlin code via platform channel.
class _AndroidMlKitOcr implements ExpenseOcrDataSource {
  static const _channel = MethodChannel('expense_tracker/ocr_android');

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

      final nativeCandidates = result['amountCandidates'] as List<dynamic>?;
      final amountCandidates = parseAmountCandidates(raw, nativeCandidates);
      if (amountCandidates.isEmpty) return null;

      return OcrResult(
        rawText: raw,
        amountCandidates: amountCandidates,
        merchant: result['merchant'] as String?,
      );
    } on PlatformException catch (e) {
      debugPrint('[Android OCR] ${e.code}: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[Android OCR] Error: $e');
      return null;
    }
  }
}
