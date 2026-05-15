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
请根据以下消费信息，从固定类别中选择一个最合适的类别。
固定类别（必须其一）：$categories

用户输入：
- 金额/金额描述: $amountText
- 备注: $note

（真实环境将向模型发送上述内容；本 Demo 仅打印并随机返回类别。）
''';
    debugPrint(prompt);
    // ignore: avoid_print
    print(prompt);

    await Future<void>.delayed(const Duration(milliseconds: 450));
    return ExpenseCategory.values[_random.nextInt(ExpenseCategory.values.length)];
  }
}
