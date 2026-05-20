import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../data/subscription_service.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/repositories/expense_repository.dart';
import '../providers/app_providers.dart';

class ExpenseListScreen extends StatelessWidget {
  const ExpenseListScreen({super.key});

  String _formatChineseDate(DateTime date) {
    return '${date.month}月${date.day}日';
  }

  Future<void> _openSettings(BuildContext context) async {
    final sub = context.read<SubscriptionService>();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('设置'),
            content: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('AI 演示模式'),
              subtitle: const Text('跳过订阅限制，用于测试 AI 分类与月报洞察'),
              value: sub.isDemoMode,
              onChanged: (enabled) async {
                if (enabled) {
                  await sub.enableDemoMode();
                } else {
                  await sub.disableDemoMode();
                }
                setDialogState(() {});
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('关闭'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final csv = await context.read<ExpenseRepository>().exportAllAsCsv();
      final docs = await getApplicationDocumentsDirectory();
      final name =
          'expenses_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${docs.path}/$name');
      await file.writeAsString(csv, flush: true);
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('已导出 CSV：\n${file.path}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('导出失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final listState = context.watch<ExpenseListController>();
    final nav = context.read<ShellNavigationController>();
    final currency = NumberFormat.currency(locale: 'zh_CN', symbol: '¥');

    return Scaffold(
      appBar: AppBar(
        title: const Text('支出'),
        actions: [
          IconButton(
            tooltip: '设置',
            onPressed: () => _openSettings(context),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: '导出 CSV',
            onPressed: () => _exportCsv(context),
            icon: const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: _buildBody(context, listState, currency),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'expense_list_fab',
        onPressed: () => nav.setTab(1),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text(
          '记一笔',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ExpenseListController listState,
    NumberFormat currency,
  ) {
    if (listState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (listState.error != null) {
      return Center(child: Text('加载失败：${listState.error}'));
    }
    final items = listState.expenses;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              const SizedBox(height: 16),
              Text(
                '还没有任何支出记录',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '点击下方「记一笔」添加第一笔支出吧',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final e = items[i];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                e.category.emoji,
                style: const TextStyle(fontSize: 18),
              ),
            ),
            title: Text(
              currency.format(e.amount),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (e.note.trim().isNotEmpty)
                  Text(
                    e.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                Text(
                  _formatChineseDate(e.date),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
            trailing: Text(
              e.category.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            isThreeLine: e.note.trim().isNotEmpty,
          ),
        );
      },
    );
  }
}
