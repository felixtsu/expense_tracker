import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase_config.dart';
import 'data/auth_service.dart';
import 'data/datasources/ai_categorization_api_data_source.dart';
import 'data/datasources/ai_insight_api_data_source.dart';
import 'data/datasources/expense_local_data_source.dart';
import 'data/datasources/expense_remote_data_source.dart';
import 'data/repositories/expense_repository_impl.dart';
import 'data/subscription_service.dart';
import 'data/sync_service.dart';
import 'domain/repositories/expense_repository.dart';
import 'presentation/providers/app_providers.dart';
import 'presentation/screens/home_shell.dart';
import 'presentation/sync_scope.dart';
import 'presentation/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN');

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  final authService = AuthService();
  await authService.ensureAnonymousSession();

  final dbPath = await getDatabasesPath();
  final db = await ExpenseLocalDataSource.open(
    ExpenseLocalDataSource.defaultDbFilePath(dbPath),
  );

  final subscriptionService = await SubscriptionService.create();
  await subscriptionService.refreshEntitlement();

  final prefs = await SharedPreferences.getInstance();
  SyncService? syncService;
  if (SupabaseConfig.isConfigured) {
    syncService = SyncService(
      local: ExpenseLocalDataSource(db),
      remote: ExpenseRemoteDataSource(Supabase.instance.client),
      subscription: subscriptionService,
      prefs: prefs,
    );
  }

  final aiApi = AiCategorizationApiDataSource();
  final aiInsightApi = AiInsightApiDataSource();

  final repository = ExpenseRepositoryImpl(
    ExpenseLocalDataSource(db),
    aiApi,
    aiInsight: aiInsightApi,
    syncService: syncService,
    accessToken: () {
      return authService.accessToken;
    },
  );

  final listController = ExpenseListController(repository);
  repository.onDataChanged = listController.load;
  await listController.load();

  if (syncService != null && subscriptionService.canUseCloudSync) {
    unawaited(syncService.syncNow(onDataChanged: listController.load));
  }

  runApp(ExpenseTrackerApp(
    repository: repository,
    subscriptionService: subscriptionService,
    syncService: syncService,
    listController: listController,
  ));
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({
    super.key,
    required this.repository,
    required this.subscriptionService,
    this.syncService,
    required this.listController,
  });

  final ExpenseRepository repository;
  final SubscriptionService subscriptionService;
  final SyncService? syncService;
  final ExpenseListController listController;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ExpenseRepository>.value(value: repository),
        Provider<SubscriptionService>.value(value: subscriptionService),
        ChangeNotifierProvider<ExpenseListController>.value(
          value: listController,
        ),
        ChangeNotifierProvider(create: (_) => ShellNavigationController()),
        ChangeNotifierProvider(create: (_) => ReportMonthController()),
      ],
      child: SyncScope(
        sync: syncService,
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
      ),
    );
  }
}
