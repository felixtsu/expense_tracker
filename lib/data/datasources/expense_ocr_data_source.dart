/// Result of scanning a receipt image.
class OcrResult {
  const OcrResult({
    required this.rawText,
    this.amount,
    this.merchant,
  });

  /// Full raw text recognized from the image.
  final String rawText;

  /// Recognized amount string (e.g. "25.50"), if any.
  final String? amount;

  /// Recognized merchant / store name, if any.
  final String? merchant;
}

/// Abstract OCR data source for expense receipt scanning.
abstract class ExpenseOcrDataSource {
  /// Scan [imagePath] and return structured data.
  /// Returns null if recognition fails.
  Future<OcrResult?> scan(String imagePath);
}
