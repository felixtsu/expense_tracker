// Standalone OCR test - run with: flutter run test_ocr.dart
// Or: dart test_ocr.dart (on Android device)
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

void main() async {
  final recognizer = TextRecognizer();
  
  // Test taxi receipt
  final taxiPath = '/Users/clawcubic/.openclaw/workspaces/builder/taxi_test.jpg';
  final taxiImage = InputImage.fromFilePath(taxiPath);
  final taxiRecognized = await recognizer.processImage(taxiImage);
  
  debugPrint('=== TAXI RECEIPT RAW OCR ===');
  debugPrint(taxiRecognized.text);
  debugPrint('=== END ===');
  
  for (final block in taxiRecognized.blocks) {
    debugPrint('Block: "${block.text}"');
    for (final line in block.lines) {
      debugPrint('  Line: "${line.text}"');
    }
  }
  
  await recognizer.close();
}
