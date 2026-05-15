import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/expense_category.dart';
import '../../domain/repositories/expense_repository.dart';
import '../providers/app_providers.dart';

List<Color> _categoryColors(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return [
    scheme.primary,
    scheme.secondary,
    scheme.tertiary,
    scheme.error,
    scheme.primaryContainer,
    scheme.secondaryContainer,
    scheme.tertiaryContainer,
    scheme.surfaceContainerHighest,
    scheme.outline,
  ];
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final month = context.watch<ReportMonthController>().month;
    final monthCtrl = context.read<ReportMonthController>();
    final listCtrl = context.watch<ExpenseListController>();
    final repo = context.read<ExpenseRepository>();
    final currency = NumberFormat.currency(locale: 'zh_CN', symbol: '¥');
    final title = DateFormat.yMMM('zh_CN').format(month);

    return Scaffold(
      appBar: AppBar(
        title: const Text('月度报表'),
        actions: [
          IconButton(
            tooltip: '上一月',
            onPressed: monthCtrl.prevMonth,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: '下一月',
            onPressed: monthCtrl.nextMonth,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<Map<ExpenseCategory, double>>(
          key: ValueKey(
            '${listCtrl.dataRevision}_${month.year}_${month.month}',
          ),
          future: repo.monthlyTotalsByCategory(month.year, month.month),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('加载失败：${snapshot.error}'));
            }
            final totals = snapshot.data!;
            final totalSum = totals.values.fold<double>(0, (a, b) => a + b);
            final colors = _categoryColors(context);
            if (totalSum <= 0) {
              return Center(
                child: Text(
                  '$title 暂无支出',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              );
            }

            final entries = ExpenseCategory.values
                .map((c) => MapEntry(c, totals[c] ?? 0))
                .where((e) => e.value > 0)
                .toList();

            final sections = <PieChartSectionData>[];
            for (var i = 0; i < entries.length; i++) {
              final e = entries[i];
              final pct = e.value / totalSum * 100;
              sections.add(
                PieChartSectionData(
                  color: colors[e.key.index % colors.length],
                  value: e.value,
                  title: '${pct.toStringAsFixed(0)}%',
                  radius: 56,
                  titleStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '合计 ${currency.format(totalSum)}',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: sections,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ListView(
                          children: entries.map((e) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: colors[e.key.index % colors.length],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      e.key.label,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(currency.format(e.value)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
