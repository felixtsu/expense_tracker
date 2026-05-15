import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../domain/repositories/expense_repository.dart';
import '../providers/app_providers.dart';

class ExpenseListScreen extends StatelessWidget {
  const ExpenseListScreen({super.key});

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
            tooltip: '导出 CSV',
            onPressed: () => _exportCsv(context),
            icon: const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: _buildBody(context, listState, currency),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => nav.setTab(1),
        icon: const Icon(Icons.add),
        label: const Text('记一笔'),
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
        child: Text(
          '暂无记录\n点击右下角「记一笔」快速添加',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.outline,
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
            title: Text(
              currency.format(e.amount),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              '${DateFormat.yMMMd('zh_CN').format(e.date)} · ${e.category.label}'
              '${e.note.trim().isEmpty ? '' : '\n${e.note}'}',
            ),
            isThreeLine: e.note.trim().isNotEmpty,
            leading: CircleAvatar(
              child: Text(
                e.category.label.substring(0, 1),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        );
      },
    );
  }
}
