import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import 'data/datasources/ai_categorization_api_data_source.dart';
import 'data/datasources/ai_insight_api_data_source.dart';
import 'data/datasources/expense_local_data_source.dart';
import 'data/repositories/expense_repository_impl.dart';
import 'data/subscription_service.dart';
import 'domain/repositories/expense_repository.dart';
import 'presentation/providers/app_providers.dart';
import 'presentation/screens/home_shell.dart';
import 'presentation/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN');
  final dbPath = await getDatabasesPath();
  final db = await ExpenseLocalDataSource.open(
    ExpenseLocalDataSource.defaultDbFilePath(dbPath),
  );

  // AI features are gated behind IAP subscription (SubscriptionService).
  // Free version: OCR only. AI categorization/insight require AI Pro subscription.
  final subscriptionService = await SubscriptionService.create();

  final aiApi = AiCategorizationApiDataSource();
  final aiInsightApi = AiInsightApiDataSource();

  final repository = ExpenseRepositoryImpl(
    ExpenseLocalDataSource(db),
    aiApi,
    aiInsight: aiInsightApi,
  );

  runApp(ExpenseTrackerApp(
    repository: repository,
    subscriptionService: subscriptionService,
  ));
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({
    super.key,
    required this.repository,
    required this.subscriptionService,
  });

  final ExpenseRepository repository;
  final SubscriptionService subscriptionService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ExpenseRepository>.value(value: repository),
        Provider<SubscriptionService>.value(value: subscriptionService),
        ChangeNotifierProvider(
          create: (_) => ExpenseListController(repository)..load(),
        ),
        ChangeNotifierProvider(create: (_) => ShellNavigationController()),
        ChangeNotifierProvider(create: (_) => ReportMonthController()),
      ],
      child: MaterialApp(
        title: 'Expense Tracker',
        theme: buildAppTheme(),
        home: const HomeShell(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('zh', 'CN'),
          Locale('en', 'US'),
        ],
        locale: const Locale('zh', 'CN'),
      ),
    );
  }
}
