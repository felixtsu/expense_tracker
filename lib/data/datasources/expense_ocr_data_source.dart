/// A single amount candidate extracted from OCR text.
class AmountCandidate {
  const AmountCandidate({
    required this.value,
    required this.raw,
    this.context,
    this.isLikelyTotal = false,
    this.isSuspicious = false,
  });

  /// Parsed decimal string, e.g. "47.40".
  final String value;

  /// Original OCR substring, e.g. "HK\$47.40".
  final String raw;

  /// Full line context, e.g. "Total: HK\$47.40".
  final String? context;

  /// Line contains total/总计/合计/金额/总额/实付/应付/小计 keywords.
  final bool isLikelyTotal;

  /// Value looks like a calendar year (1900~2100 with .00).
  final bool isSuspicious;

  factory AmountCandidate.fromMap(Map<dynamic, dynamic> map) {
    return AmountCandidate(
      value: map['value'] as String? ?? '',
      raw: map['raw'] as String? ?? '',
      context: map['context'] as String?,
      isLikelyTotal: map['isLikelyTotal'] as bool? ?? false,
      isSuspicious: map['isSuspicious'] as bool? ?? false,
    );
  }
}

/// Result returned by an OCR scan.
class OcrResult {
  const OcrResult({
    required this.rawText,
    required this.amountCandidates,
    this.merchant,
  });

  /// Full raw text recognized from the image.
  final String rawText;

  /// All amount candidates found in the receipt.
  final List<AmountCandidate> amountCandidates;

  /// Recognized merchant / store name, or null.
  final String? merchant;
}

/// Parse [amountCandidates] from native channel payload, or fall back to [rawText].
List<AmountCandidate> parseAmountCandidates(
  String rawText,
  List<dynamic>? nativeCandidates,
) {
  if (nativeCandidates != null && nativeCandidates.isNotEmpty) {
    return nativeCandidates
        .whereType<Map>()
        .map((m) => AmountCandidate.fromMap(m))
        .where((c) => c.value.isNotEmpty)
        .toList()
      ..sort(_sortCandidates);
  }
  return extractAmountCandidatesFromText(rawText);
}

int _sortCandidates(AmountCandidate a, AmountCandidate b) {
  if (a.isLikelyTotal != b.isLikelyTotal) {
    return a.isLikelyTotal ? -1 : 1;
  }
  if (a.isSuspicious != b.isSuspicious) {
    return a.isSuspicious ? 1 : -1;
  }
  final av = double.tryParse(a.value) ?? 0;
  final bv = double.tryParse(b.value) ?? 0;
  return bv.compareTo(av);
}

final _totalLinePattern = RegExp(
  r'(?:total|amount|總(?:額|计|計)|合计|总计|金额|总额|实付|应付|小计|小計)',
  caseSensitive: false,
);

final _amountPattern = RegExp(
  r"((?:HKD|HK\$|HK＄|\bHK(?!D)(?:['\$＄])?|港(?:币|幣)|[¥￥＄]|\$)\s*)?"
  r"(-)?(\d{1,3}(?:,\d{3})*|\d+)\.(\d{2})\b",
  caseSensitive: false,
);

bool _isSuspiciousAmount(double v) {
  final whole = v.floor();
  if (whole < 1900 || whole > 2100) return false;
  return (v - whole).abs() < 0.0001;
}

/// Line-by-line fallback when native layer does not return candidates.
List<AmountCandidate> extractAmountCandidatesFromText(String text) {
  final seen = <String>{};
  final candidates = <AmountCandidate>[];

  for (final line in text.split(RegExp(r'\r?\n'))) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    final isLikelyTotal = _totalLinePattern.hasMatch(trimmed);

    for (final m in _amountPattern.allMatches(trimmed)) {
      final prefix = m.group(1) ?? '';
      final sign = m.group(2) ?? '';
      final intPart = (m.group(3) ?? '').replaceAll(',', '');
      final decPart = m.group(4) ?? '';
      if (intPart.isEmpty || decPart.isEmpty) continue;

      final parsed = double.tryParse('$sign$intPart.$decPart');
      final value = parsed != null
          ? parsed.abs().toStringAsFixed(2)
          : '$intPart.$decPart';
      final raw = m.group(0) ?? '$prefix$intPart.$decPart';
      final key = '$value|$raw|$trimmed';
      if (!seen.add(key)) continue;

      final v = double.tryParse(value) ?? 0;
      candidates.add(
        AmountCandidate(
          value: value,
          raw: raw.trim(),
          context: trimmed,
          isLikelyTotal: isLikelyTotal,
          isSuspicious: _isSuspiciousAmount(v),
        ),
      );
    }
  }

  candidates.sort(_sortCandidates);
  return candidates;
}

/// Abstract interface for receipt OCR data sources.
abstract class ExpenseOcrDataSource {
  /// Scan a receipt image and extract amount candidates + merchant.
  /// Returns null if recognition failed or no text was found.
  Future<OcrResult?> scan(String imagePath);
}
