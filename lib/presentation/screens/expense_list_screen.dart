import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/supabase_config.dart';
import '../../data/subscription_service.dart';
import '../../data/sync_service.dart';
import '../../domain/repositories/expense_repository.dart';
import '../providers/app_providers.dart';
import '../sync_scope.dart';

class ExpenseListScreen extends StatelessWidget {
  const ExpenseListScreen({super.key});

  String _formatChineseDate(DateTime date) {
    return '${date.month}月${date.day}日';
  }

  String _syncStatusLabel(SyncService? sync) {
    if (!SupabaseConfig.isConfigured) return '未設定 Supabase';
    if (sync == null) return '同步未啟用';
    return switch (sync.state) {
      SyncState.idle => '已準備好',
      SyncState.syncing => '同步中…',
      SyncState.error => '同步失敗',
    };
  }

  Future<void> _openSettings(BuildContext context) async {
    final sub = context.read<SubscriptionService>();
    final sync = SyncScope.maybeOf(context);
    final listController = context.read<ExpenseListController>();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          Widget settingsBody() {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('AI 示範模式'),
                  subtitle: const Text(
                    '跳過訂閱限制，用於測試 AI 分類、月報洞察與雲端同步',
                  ),
                  value: sub.isDemoMode,
                  onChanged: (enabled) async {
                    if (enabled) {
                      await sub.enableDemoMode();
                    } else {
                      await sub.disableDemoMode();
                    }
                    if (sync != null && sub.canUseCloudSync) {
                      await sync.syncNow(
                        onDataChanged: listController.load,
                      );
                    }
                    setDialogState(() {});
                  },
                ),
                if (SupabaseConfig.isConfigured) ...[
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('雲端同步'),
                    subtitle: Text(
                      '${_syncStatusLabel(sync)}\n'
                      'Pro：${sub.isAiProActive ? "是" : "否"}',
                    ),
                  ),
                  if (sync != null && sub.canUseCloudSync)
                    TextButton(
                      onPressed: sync.state == SyncState.syncing
                          ? null
                          : () async {
                              await sync.syncNow(
                                onDataChanged: listController.load,
                              );
                              setDialogState(() {});
                            },
                      child: const Text('立即同步'),
                    ),
                ],
                if (kDebugMode && SupabaseConfig.isConfigured) ...[
                  const Divider(),
                  TextButton(
                    onPressed: () async {
                      const secret = String.fromEnvironment('DEV_PRO_SECRET');
                      if (secret.isEmpty) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '請用 --dart-define=DEV_PRO_SECRET=... 建置',
                              ),
                            ),
                          );
                        }
                        return;
                      }
                      final ok = await sub.activateProForDev(secret: secret);
                      if (sync != null && ok) {
                        await sync.syncNow(
                          onDataChanged: listController.load,
                        );
                      }
                      setDialogState(() {});
                    },
                    child: const Text('開發：啟用 Pro（伺服器端）'),
                  ),
                ],
              ],
            );
          }

          return AlertDialog(
            title: const Text('設定'),
            content: SingleChildScrollView(
              child: sync != null
                  ? ListenableBuilder(
                      listenable: sync,
                      builder: (_, __) => settingsBody(),
                    )
                  : settingsBody(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('關閉'),
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
        SnackBar(content: Text('已匯出 CSV：\n${file.path}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('匯出失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final listState = context.watch<ExpenseListController>();
    final nav = context.read<ShellNavigationController>();
    final currency = NumberFormat.currency(locale: 'zh_HK', symbol: 'HK\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('支出'),
        actions: [
          IconButton(
            tooltip: '設定',
            onPressed: () => _openSettings(context),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: '匯出 CSV',
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
          '記一筆',
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
      return Center(child: Text('載入失敗：${listState.error}'));
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
                '還沒有任何支出記錄',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '點擊下方「記一筆」新增第一筆支出吧',
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
