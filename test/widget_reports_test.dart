import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_tracker_app/data/subscription_service.dart';
import 'package:expense_tracker_app/domain/entities/expense.dart';
import 'package:expense_tracker_app/domain/entities/expense_category.dart';
import 'package:expense_tracker_app/domain/repositories/expense_repository.dart';
import 'package:expense_tracker_app/presentation/providers/app_providers.dart';
import 'package:expense_tracker_app/presentation/screens/reports_screen.dart';

class MockExpenseRepository implements ExpenseRepository {
  final Map<String, List<Expense>> _expensesByMonth = {};

  void setExpensesForMonth(int year, int month, List<Expense> expenses) {
    _expensesByMonth['$year-$month'] = expenses;
  }

  @override
  Future<List<Expense>> getAll() async {
    return _expensesByMonth.values.expand((e) => e).toList();
  }

  @override
  Future<void> insert(Expense expense) async {}

  @override
  Future<void> delete(int id) async {}

  @override
  Future<void> update(Expense expense) async {}

  @override
  Future<Map<ExpenseCategory, double>> monthlyTotalsByCategory(int year, int month) async {
    final expenses = _expensesByMonth['$year-$month'] ?? [];
    final result = <ExpenseCategory, double>{};
    for (final e in expenses) {
      result[e.category] = (result[e.category] ?? 0) + e.amount;
    }
    return result;
  }

  @override
  Future<String> exportAllAsCsv() async => '';

  @override
  Future<ExpenseCategory> suggestCategoryWithMockAi({
    required String amountText,
    required String note,
  }) async =>
      ExpenseCategory.dining;

  @override
  Future<String> generateMonthlyInsight({
    required int year,
    required int month,
    required Map<String, double> totals,
  }) async =>
      'Mock insight';
}

Future<void> main() async {
  await initializeDateFormatting('zh_CN');

  late MockExpenseRepository mockRepo;
  late SubscriptionService mockSub;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    mockRepo = MockExpenseRepository();
    mockSub = await SubscriptionService.create();
  });

  Widget buildTestableWidget(Widget child) {
    return MultiProvider(
      providers: [
        Provider<ExpenseRepository>.value(value: mockRepo),
        Provider<SubscriptionService>.value(value: mockSub),
        ChangeNotifierProvider(create: (_) => ExpenseListController(mockRepo)),
        ChangeNotifierProvider(create: (_) => ShellNavigationController()),
        ChangeNotifierProvider(create: (_) => ReportMonthController()),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh', 'CN')],
        home: Scaffold(body: child),
      ),
    );
  }

  group('ReportsScreen', () {
    testWidgets('pie chart renders when monthly data exists', (tester) async {
      final now = DateTime.now();

      // Pre-populate current month with expenses
      mockRepo.setExpensesForMonth(now.year, now.month, [
        Expense(id: 1, amount: 100.0, category: ExpenseCategory.dining, note: '午餐', date: now),
        Expense(id: 2, amount: 50.0, category: ExpenseCategory.transport, note: '打车', date: now),
      ]);

      await tester.pumpWidget(
        buildTestableWidget(const ReportsScreen()),
      );

      // Wait for the FutureBuilder to complete
      await tester.pumpAndSettle();

      // PieChart should be present
      expect(find.byType(PieChart), findsOneWidget);

      // Total amount should be shown
      expect(find.text('合计 ¥150.00'), findsOneWidget);

      // Category legend items should be present
      expect(find.text('餐饮'), findsWidgets);
      expect(find.text('交通'), findsWidgets);
    });

    testWidgets('shows empty message when no data for the month', (tester) async {
      final now = DateTime.now();
      // No expenses for current month
      mockRepo.setExpensesForMonth(now.year, now.month, []);

      await tester.pumpWidget(
        buildTestableWidget(const ReportsScreen()),
      );
      await tester.pumpAndSettle();

      // Should show empty state with month name
      final monthLabel = '${now.year}年${now.month}月';
      expect(find.text('$monthLabel 暂无支出'), findsOneWidget);

      // No PieChart should be shown
      expect(find.byType(PieChart), findsNothing);
    });

    testWidgets('month navigation buttons are present', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const ReportsScreen()),
      );
      await tester.pumpAndSettle();

      // Previous/next month buttons
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });
}
