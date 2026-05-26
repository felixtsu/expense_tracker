import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../domain/entities/expense_category.dart';

/// Mock OpenAI-style categorization: logs the full prompt, returns a random category.
class AiCategorizationMockDataSource {
  final Random _random = Random();

  Future<ExpenseCategory> suggestCategory({
    required String amountText,
    required String note,
  }) async {
    final categories = ExpenseCategory.values.map((e) => e.label).join('、');
    final prompt = '''
[Mock OpenAI API — expense categorization]
請根據以下消費資料，從固定類別中選擇一個最合適的類別。
固定類別（必須其一）：$categories

用戶輸入：
- 金額/金額描述: $amountText
- 備註: $note

（真實環境會將上述內容發送給模型；本 Demo 只打印並隨機返回類別。）
''';
    debugPrint(prompt);
    // ignore: avoid_print
    print(prompt);

    await Future<void>.delayed(const Duration(milliseconds: 450));
    return ExpenseCategory
        .values[_random.nextInt(ExpenseCategory.values.length)];
  }
}
