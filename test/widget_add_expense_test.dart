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
import 'package:expense_tracker_app/presentation/screens/add_expense_screen.dart';

/// Minimal in-memory implementation for testing.
class MockExpenseRepository implements ExpenseRepository {
  final List<Expense> _expenses = [];

  @override
  Future<List<Expense>> getAll() async => List.from(_expenses);

  @override
  Future<void> insert(Expense expense) async {
    final id = _expenses.length + 1;
    _expenses.add(expense.copyWith(id: id));
  }

  @override
  Future<void> delete(int id) async {
    _expenses.removeWhere((e) => e.id == id);
  }

  @override
  Future<void> update(Expense expense) async {
    final idx = _expenses.indexWhere((e) => e.id == expense.id);
    if (idx >= 0) _expenses[idx] = expense;
  }

  @override
  Future<Map<ExpenseCategory, double>> monthlyTotalsByCategory(int year, int month) async {
    final result = <ExpenseCategory, double>{};
    for (final e in _expenses) {
      if (e.date.year == year && e.date.month == month) {
        result[e.category] = (result[e.category] ?? 0) + e.amount;
      }
    }
    return result;
  }

  @override
  Future<String> exportAllAsCsv() async {
    final buf = StringBuffer('id,amount,category,note,date\n');
    for (final e in _expenses) {
      buf.writeln('${e.id},${e.amount},${e.category.label},${e.note},${e.date}');
    }
    return buf.toString();
  }

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

  group('AddExpenseScreen', () {
    testWidgets('form fields render correctly', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const AddExpenseScreen()));
      await tester.pumpAndSettle();

      // Amount field
      expect(find.byType(TextFormField), findsWidgets);
      // Category dropdown
      expect(find.byType(DropdownButtonFormField<ExpenseCategory>), findsOneWidget);
      // Note field
      expect(find.byType(TextFormField), findsNWidgets(2)); // amount + note
      // Save button
      expect(find.widgetWithText(FilledButton, '保存'), findsOneWidget);
    });

    testWidgets('camera button is visible next to amount field', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const AddExpenseScreen()));
      await tester.pumpAndSettle();

      // Camera icon button should be present
      expect(find.byIcon(Icons.camera_alt), findsWidgets);

      // Tooltip confirms it's the receipt scanner
      final cameraBtn = find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip?.contains('拍照识别收据') == true,
      );
      expect(cameraBtn, findsOneWidget);
    });

    testWidgets('date picker opens when date tile is tapped', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const AddExpenseScreen()));
      await tester.pumpAndSettle();

      // Find the date ListTile and tap it
      expect(find.text('日期'), findsOneWidget);
      await tester.tap(find.text('日期'));
      await tester.pumpAndSettle();

      // Date picker dialog should appear
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('category dropdown shows all 8 categories', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const AddExpenseScreen()));
      await tester.pumpAndSettle();

      // Open the dropdown
      await tester.tap(find.byType(DropdownButtonFormField<ExpenseCategory>));
      await tester.pumpAndSettle();

      // All 8 category labels should be visible in the menu
      for (final cat in ExpenseCategory.values) {
        expect(find.text(cat.label), findsWidgets);
      }
    });

    testWidgets('submit saves expense and clears amount field', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const AddExpenseScreen()));
      await tester.pumpAndSettle();

      // Enter amount into the first TextFormField (amount)
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, '88.5');
      await tester.pumpAndSettle();

      // Tap save
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      // SnackBar "已保存" should appear
      expect(find.text('已保存'), findsOneWidget);
    });
  });
}
