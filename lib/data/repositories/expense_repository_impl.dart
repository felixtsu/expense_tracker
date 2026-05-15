import 'package:intl/intl.dart';

import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/repositories/expense_repository.dart';
import '../datasources/ai_categorization_mock_data_source.dart';
import '../datasources/expense_local_data_source.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  ExpenseRepositoryImpl(this._local, this._ai);

  final ExpenseLocalDataSource _local;
  final AiCategorizationMockDataSource _ai;

  @override
  Future<List<Expense>> getAll() => _local.getAllOrdered();

  @override
  Future<void> insert(Expense expense) => _local.insert(expense);

  @override
  Future<Map<ExpenseCategory, double>> monthlyTotalsByCategory(
    int year,
    int month,
  ) =>
      _local.monthlyTotalsByCategory(year, month);

  @override
  Future<String> exportAllAsCsv() async {
    final list = await _local.getAllOrdered();
    final esc = NumberFormat('#0.##', 'en_US');
    final buf = StringBuffer();
    buf.writeln('date,amount,category,note');
    for (final e in list) {
      final note = _csvEscape(e.note);
      buf.writeln(
        '${e.date.toIso8601String()},${esc.format(e.amount)},${e.category.label},$note',
      );
    }
    return buf.toString();
  }

  String _csvEscape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  @override
  Future<ExpenseCategory> suggestCategoryWithMockAi({
    required String amountText,
    required String note,
  }) {
    return _ai.suggestCategory(amountText: amountText, note: note);
  }
}
