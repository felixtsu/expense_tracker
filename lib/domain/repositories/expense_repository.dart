import '../entities/expense.dart';
import '../entities/expense_category.dart';

abstract class ExpenseRepository {
  Future<List<Expense>> getAll();

  Future<void> insert(Expense expense);

  /// Totals per category for [year] and [month] (1–12).
  Future<Map<ExpenseCategory, double>> monthlyTotalsByCategory(int year, int month);

  /// Full CSV including header row (UTF-8).
  Future<String> exportAllAsCsv();

  /// Mock AI: logs prompt, returns a random category for demo.
  Future<ExpenseCategory> suggestCategoryWithMockAi({
    required String amountText,
    required String note,
  });

  /// Generate an AI-written monthly spending insight in Chinese.
  /// [totals] maps category labels (String) to amounts.
  Future<String> generateMonthlyInsight({
    required int year,
    required int month,
    required Map<String, double> totals,
  });
}
