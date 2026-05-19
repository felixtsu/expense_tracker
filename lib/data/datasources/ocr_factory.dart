import 'dart:io';

import 'package:flutter/services.dart';

import 'expense_ocr_data_source.dart';
import 'apple_vision_ocr_data_source.dart';

export 'expense_ocr_data_source.dart' show OcrResult, ExpenseOcrDataSource;

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
    throw UnsupportedError('OCR not supported on this platform');
  }
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
      if (result == null || result['text'] == null) return null;
      return OcrResult(
        rawText: result['text'] as String,
        amount: result['amount'] as String?,
        merchant: result['merchant'] as String?,
      );
    } catch (e) {
      return null;
    }
  }
}
