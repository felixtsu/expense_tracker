import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/foundation.dart';

void main() {
  test('MLKit taxi receipt OCR - get raw text', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final recognizer = TextRecognizer();

    // Taxi receipt
    final taxiPath = '/Users/clawcubic/.openclaw/workspaces/builder/taxi_test.jpg';
    final taxiImage = InputImage.fromFilePath(taxiPath);
    final taxiRecognized = await recognizer.processImage(taxiImage);

    debugPrint('=== TAXI RECEIPT RAW OCR ===');
    debugPrint(taxiRecognized.text);
    debugPrint('=== END ===');

    debugPrint('\n=== ALL LINES ===');
    for (final block in taxiRecognized.blocks) {
      for (final line in block.lines) {
        debugPrint('LINE: "${line.text}"');
      }
    }

    // Restaurant receipt
    final restPath = '/Users/clawcubic/.openclaw/workspaces/builder/restaurant_test.jpg';
    final restImage = InputImage.fromFilePath(restPath);
    final restRecognized = await recognizer.processImage(restImage);

    debugPrint('\n=== RESTAURANT RECEIPT RAW OCR ===');
    debugPrint(restRecognized.text);
    debugPrint('=== END ===');

    for (final block in restRecognized.blocks) {
      for (final line in block.lines) {
        debugPrint('LINE: "${line.text}"');
      }
    }

    await recognizer.close();
  });
}
