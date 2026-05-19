import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/api_config.dart';

/// Calls our Vercel serverless function for AI-powered monthly insight generation.
class AiInsightApiDataSource {
  AiInsightApiDataSource({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// [totals] is a map of category label -> amount.
  /// Returns a short Chinese insight string (2-3 sentences).
  Future<String> generateMonthlyInsight({
    required int year,
    required int month,
    required Map<String, double> totals,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/insight');

    // Convert double values to int (cents) to avoid floating point precision issues
    final intTotals = <String, int>{};
    for (final e in totals.entries) {
      intTotals[e.key] = (e.value * 100).round();
    }

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'year': year,
        'month': month,
        'totals': intTotals,
      }),
    );

    if (response.statusCode != 200) {
      debugPrint('[insight] HTTP ${response.statusCode}: ${response.body}');
      throw Exception('洞察服务暂时不可用 (${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final insight = json['insight'] as String? ?? '';
    return insight;
  }
}
