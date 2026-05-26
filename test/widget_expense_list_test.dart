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
import 'package:expense_tracker_app/presentation/screens/expense_list_screen.dart';

class MockExpenseRepository implements ExpenseRepository {
  List<Expense> _expenses = [];

  void setExpenses(List<Expense> expenses) {
    _expenses = List.from(expenses);
  }

  @override
  Future<List<Expense>> getAll() async => List.from(_expenses);

  @override
  Future<void> insert(Expense expense) async {}

  @override
  Future<Map<ExpenseCategory, double>> monthlyTotalsByCategory(
          int year, int month) async =>
      {};

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
      '';
}

Future<void> main() async {
  await initializeDateFormatting('zh_HK');

  late MockExpenseRepository mockRepo;
  late SubscriptionService mockSub;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    mockRepo = MockExpenseRepository();
    mockSub = await SubscriptionService.create();
  });

  Widget buildTestableWidget({
    required ExpenseListController controller,
  }) {
    return MultiProvider(
      providers: [
        Provider<ExpenseRepository>.value(value: mockRepo),
        ChangeNotifierProvider<SubscriptionService>.value(value: mockSub),
        ChangeNotifierProvider<ExpenseListController>.value(value: controller),
        ChangeNotifierProvider(create: (_) => ShellNavigationController()),
        ChangeNotifierProvider(create: (_) => ReportMonthController()),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('zh', 'HK'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh', 'HK')],
        home: const ExpenseListScreen(),
      ),
    );
  }

  group('ExpenseListScreen', () {
    testWidgets('empty state shows encouraging message and tip',
        (tester) async {
      mockRepo.setExpenses([]);
      final controller = ExpenseListController(mockRepo);
      await controller
          .load(); // Pre-load so widget doesn't have to deal with async

      await tester.pumpWidget(buildTestableWidget(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('還沒有任何支出記錄'), findsOneWidget);
      expect(find.text('點擊下方「記一筆」新增第一筆支出吧'), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('list items show category emoji, amount, note, and date',
        (tester) async {
      final now = DateTime.now();
      mockRepo.setExpenses([
        Expense(
          id: 1,
          amount: 25.5,
          category: ExpenseCategory.dining,
          note: '午餐麻辣燙',
          date: DateTime(now.year, now.month, 15),
        ),
        Expense(
          id: 2,
          amount: 120.0,
          category: ExpenseCategory.transport,
          note: '的士回家',
          date: DateTime(now.year, now.month, 14),
        ),
      ]);
      final controller = ExpenseListController(mockRepo);
      await controller.load();

      await tester.pumpWidget(buildTestableWidget(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('HK\$25.50'), findsOneWidget);
      expect(find.text('HK\$120.00'), findsOneWidget);
      expect(find.text('午餐麻辣燙'), findsOneWidget);
      expect(find.text('的士回家'), findsOneWidget);
      expect(find.text('🍜'), findsOneWidget);
      expect(find.text('🚕'), findsOneWidget);
      expect(find.text('${now.month}月15日'), findsOneWidget);
      expect(find.text('${now.month}月14日'), findsOneWidget);
      expect(find.text('餐飲'), findsOneWidget);
      expect(find.text('交通'), findsOneWidget);
    });

    testWidgets('FAB is present for navigation', (tester) async {
      mockRepo.setExpenses([]);
      final controller = ExpenseListController(mockRepo);
      await controller.load();

      await tester.pumpWidget(buildTestableWidget(controller: controller));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('記一筆'), findsOneWidget);
    });
  });
}
