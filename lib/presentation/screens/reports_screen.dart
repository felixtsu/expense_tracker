import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/subscription_service.dart';
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

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  /// Cached insight text per month key (e.g. "2025_5").
  final Map<String, String> _cachedInsights = {};

  /// The insight currently displayed (null = not yet generated).
  String? _currentInsight;

  /// Whether an AI call is in flight.
  bool _loadingInsight = false;

  /// The month key for which _currentInsight is valid.
  String? _insightForMonth;

  @override
  Widget build(BuildContext context) {
    final month = context.watch<ReportMonthController>().month;
    final monthCtrl = context.read<ReportMonthController>();
    final listCtrl = context.watch<ExpenseListController>();
    final repo = context.read<ExpenseRepository>();
    final currency = NumberFormat.currency(locale: 'zh_HK', symbol: 'HK\$');
    final title = DateFormat.yMMM('zh_HK').format(month);
    final monthKey = '${month.year}_${month.month}';

    // Invalidate cached insight when month changes to a month we haven't
    // generated an insight for yet.
    if (_insightForMonth != monthKey) {
      _currentInsight = _cachedInsights[monthKey];
      _insightForMonth = _currentInsight != null ? monthKey : null;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('月度報表'),
        actions: [
          IconButton(
            tooltip: '上一個月',
            onPressed: monthCtrl.prevMonth,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: '下一個月',
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
              return Center(child: Text('載入失敗：${snapshot.error}'));
            }
            final totals = snapshot.data!;
            final totalSum = totals.values.fold<double>(0, (a, b) => a + b);
            final colors = _categoryColors(context);
            if (totalSum <= 0) {
              return Center(
                child: Text(
                  '$title 暫無支出',
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
                  '合計 ${currency.format(totalSum)}',
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
                                      color:
                                          colors[e.key.index % colors.length],
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

                // ── AI Insight section ──────────────────────────────────

                const SizedBox(height: 16),

                // Show cached/generate insight
                if (_currentInsight != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('✨ '),
                            Text(
                              'AI 月報洞察',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentInsight!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // AI Insight button — gated by IAP
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildInsightButton(context, month, totals, monthKey),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _generateInsight(
    BuildContext context,
    DateTime month,
    Map<ExpenseCategory, double> totals,
    String monthKey,
  ) async {
    final sub = context.read<SubscriptionService>();
    final repo = context.read<ExpenseRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final error = sub.checkAiAccess();
    if (error != null) {
      _showAiProPrompt(context);
      return;
    }

    setState(() => _loadingInsight = true);

    try {
      final stringTotals = <String, double>{};
      for (final e in totals.entries) {
        if (e.value > 0) {
          stringTotals[e.key.label] = e.value;
        }
      }

      final insight = await repo.generateMonthlyInsight(
        year: month.year,
        month: month.month,
        totals: stringTotals,
      );

      await sub.consumeAiCall();

      setState(() {
        _currentInsight = insight;
        _insightForMonth = monthKey;
        _cachedInsights[monthKey] = insight;
        _loadingInsight = false;
      });
    } catch (e) {
      setState(() => _loadingInsight = false);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('AI 洞察生成失敗：$e')),
        );
      }
    }
  }

  void _showAiProPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🔒 AI Pro 訂閱'),
        content: const Text(
          'AI 月報洞察是 AI Pro 功能。訂閱後可解鎖：\n'
          '• 無限次 AI 月報洞察\n'
          '• AI 智能分類\n'
          '• 雲端數據備份\n\n'
          '訂閱費用按實際 Token 用量計費。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('不用了'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('IAP 購買流程開發中…')),
              );
            },
            child: const Text('立即訂閱'),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightButton(
    BuildContext context,
    DateTime month,
    Map<ExpenseCategory, double> totals,
    String monthKey,
  ) {
    final sub = context.watch<SubscriptionService>();
    final blocked = sub.checkAiAccess() != null;

    if (blocked) {
      return OutlinedButton.icon(
        onPressed: () => _showAiProPrompt(context),
        icon: const Icon(Icons.lock, size: 18),
        label: const Text('🔒 AI 月報洞察（AI Pro）'),
      );
    }

    return FilledButton.icon(
      onPressed: _loadingInsight
          ? null
          : () => _generateInsight(context, month, totals, monthKey),
      icon: _loadingInsight
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.auto_awesome, size: 18),
      label: Text(
        _loadingInsight
            ? '生成中…'
            : _currentInsight != null
                ? '重新生成'
                : '✨ AI 月報洞察',
      ),
    );
  }
}
