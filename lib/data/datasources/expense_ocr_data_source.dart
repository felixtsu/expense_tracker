/// Result returned by an OCR scan.
class OcrResult {
  const OcrResult({
    required this.rawText,
    required this.amount,
    required this.merchant,
  });

  /// Full raw text recognized from the image.
  final String rawText;

  /// Recognized total amount as a decimal string (e.g. "128.50"), or null.
  final String? amount;

  /// Recognized merchant / store name, or null.
  final String? merchant;
}

/// Abstract interface for receipt OCR data sources.
abstract class ExpenseOcrDataSource {
  /// Scan a receipt image and extract amount + merchant.
  /// Returns null if recognition failed or no text was found.
  Future<OcrResult?> scan(String imagePath);
}
