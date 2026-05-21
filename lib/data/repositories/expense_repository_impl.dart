import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/repositories/expense_repository.dart';
import '../datasources/ai_categorization_api_data_source.dart';
import '../datasources/ai_categorization_mock_data_source.dart';
import '../datasources/ai_insight_api_data_source.dart';
import '../datasources/expense_local_data_source.dart';
import '../sync_service.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  ExpenseRepositoryImpl(
    this._local,
    this._aiApi, {
    AiCategorizationMockDataSource? aiMock,
    AiInsightApiDataSource? aiInsight,
    SyncService? syncService,
    String? Function()? accessToken,
  })  : _aiMock = aiMock ?? AiCategorizationMockDataSource(),
        _aiInsight = aiInsight,
        _sync = syncService,
        _accessToken = accessToken;

  final ExpenseLocalDataSource _local;
  final AiCategorizationApiDataSource _aiApi;
  final AiCategorizationMockDataSource _aiMock;
  final AiInsightApiDataSource? _aiInsight;
  final SyncService? _sync;
  final String? Function()? _accessToken;

  VoidCallback? onDataChanged;

  @override
  Future<List<Expense>> getAll() => _local.getAllOrdered();

  @override
  Future<void> insert(Expense expense) async {
    final withMeta = expense.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: ExpenseSyncStatus.pending,
    );
    final localId = await _local.insert(withMeta);
    final inserted = withMeta.copyWith(id: localId);

    final sync = _sync;
    if (sync != null) {
      await sync.pushOne(inserted, onDataChanged: onDataChanged);
    }
  }

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
  }) async {
    try {
      return await _aiApi.suggestCategory(
        amountText: amountText,
        note: note,
        accessToken: _accessToken?.call(),
      );
    } catch (e) {
      // ignore: avoid_print
      print('[AiCategorization] API failed, using mock fallback: $e');
      return _aiMock.suggestCategory(amountText: amountText, note: note);
    }
  }

  @override
  Future<String> generateMonthlyInsight({
    required int year,
    required int month,
    required Map<String, double> totals,
  }) async {
    if (_aiInsight == null) {
      throw Exception('AiInsightApiDataSource not configured');
    }
    return _aiInsight.generateMonthlyInsight(
      year: year,
      month: month,
      totals: totals,
      accessToken: _accessToken?.call(),
    );
  }
}
