import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/api_config.dart';
import '../../domain/entities/expense_category.dart';

/// Calls our Vercel serverless function for AI expense categorization.
/// API key is kept on the server side — safe to ship in the app.
class AiCategorizationApiDataSource {
  AiCategorizationApiDataSource({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// Returns the most likely [ExpenseCategory] for the given amount + note.
  Future<ExpenseCategory> suggestCategory({
    required String amountText,
    required String note,
    String? accessToken,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/categorize');

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    final response = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode({'amount': amountText, 'note': note}),
    );

    if (response.statusCode != 200) {
      debugPrint('[categorize] HTTP ${response.statusCode}: ${response.body}');
      throw Exception('分類服務暫時不可用 (${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final label = json['category'] as String? ?? '其他';

    return _categoryFromLabel(label);
  }

  ExpenseCategory _categoryFromLabel(String label) {
    final entry = ExpenseCategory.values.cast<ExpenseCategory?>().firstWhere(
          (e) => e!.label == label,
          orElse: () => null,
        );
    return entry ?? ExpenseCategory.other;
  }
}
