import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_providers.dart';
import 'add_expense_screen.dart';
import 'expense_list_screen.dart';
import 'reports_screen.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final tab = context.watch<ShellNavigationController>().tabIndex;
    final nav = context.read<ShellNavigationController>();

    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: const [
          ExpenseListScreen(),
          AddExpenseScreen(),
          ReportsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: nav.setTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '支出',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: '記一筆',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: '報表',
          ),
        ],
      ),
    );
  }
}
