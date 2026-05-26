import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/datasources/ocr_factory.dart';
import '../../data/subscription_service.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/repositories/expense_repository.dart';
import '../providers/app_providers.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.other;
  DateTime _date = DateTime.now();
  bool _aiBusy = false;
  bool _scanBusy = false;
  final _ocr = createOcrDataSource();
  final _picker = ImagePicker();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _scanReceipt() async {
    // Show bottom sheet to let user choose camera or gallery.
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('拍照'),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('從相簿選擇'),
            onTap: () => Navigator.pop(ctx, 'gallery'),
          ),
        ],
      ),
    );
    if (choice == null) return;

    final isCamera = choice == 'camera';

    setState(() => _scanBusy = true);
    XFile? xFile;
    try {
      xFile = await _picker.pickImage(
        source: isCamera ? ImageSource.camera : ImageSource.gallery,
        preferredCameraDevice:
            isCamera ? CameraDevice.rear : CameraDevice.front,
      );
    } on PlatformException catch (e) {
      // iOS Simulator camera not available — fall back to gallery silently
      if (e.code == 'camera_not_available') {
        xFile = await _picker.pickImage(source: ImageSource.gallery);
      } else {
        rethrow;
      }
    }
    if (xFile == null) {
      setState(() => _scanBusy = false);
      return;
    }

    try {
      final result = await _ocr.scan(xFile.path);
      if (result == null || result.amountCandidates.isEmpty) {
        _showSnackBar('未能識別，請手動輸入');
        return;
      }

      if (!mounted) return;
      final selected = await showModalBottomSheet<AmountCandidate>(
        context: context,
        builder: (ctx) => _AmountCandidateSheet(
          candidates: result.amountCandidates,
          onCustomInput: () => Navigator.pop(ctx),
        ),
        isScrollControlled: true,
      );

      if (selected != null) {
        setState(() {
          _amountController.text = selected.value;
        });
      }

      if (result.merchant != null && result.merchant!.isNotEmpty) {
        setState(() {
          _noteController.text = result.merchant!;
        });
      }

      _showSnackBar('已識別 ${result.amountCandidates.length} 個金額，請確認');
    } catch (e) {
      _showSnackBar('拍照識別失敗：$e');
    } finally {
      if (mounted) setState(() => _scanBusy = false);
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showAiProPrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🔒 AI Pro 訂閱'),
        content: const Text(
          'AI 自動分類是 AI Pro 功能。訂閱後可解鎖：\n'
          '• 無限次 AI 分類\n'
          '• AI 月報洞察\n'
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
              // TODO: open IAP purchase flow
              _showSnackBar('IAP 購買流程開發中…');
            },
            child: const Text('立即訂閱'),
          ),
        ],
      ),
    );
  }

  Future<void> _runAiCategorize() async {
    final sub = context.read<SubscriptionService>();
    final error = sub.checkAiAccess();
    if (error != null) {
      _showAiProPrompt();
      return;
    }

    setState(() => _aiBusy = true);
    try {
      final repo = context.read<ExpenseRepository>();
      final cat = await repo.suggestCategoryWithMockAi(
        amountText: _amountController.text.trim(),
        note: _noteController.text.trim(),
      );
      await sub.consumeAiCall();
      if (mounted) setState(() => _category = cat);
    } catch (e) {
      if (mounted) _showSnackBar('AI 分類失敗：$e');
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.trim());
    final expense = Expense(
      amount: amount,
      category: _category,
      note: _noteController.text.trim(),
      date: _date,
    );
    await context.read<ExpenseListController>().add(expense);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已儲存')),
    );
    _amountController.clear();
    _noteController.clear();
    setState(() {
      _category = ExpenseCategory.other;
      _date = DateTime.now();
    });
    context.read<ShellNavigationController>().setTab(0);
  }

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionService>();
    final aiBlocked = sub.checkAiAccess() != null;

    return Scaffold(
      appBar: AppBar(title: const Text('記一筆')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Amount + Camera (always free)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '金額',
                        prefixText: 'HK\$ ',
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return '請輸入金額';
                        final n = double.tryParse(t);
                        if (n == null || n <= 0) return '請輸入有效正數';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    onPressed: _scanBusy ? null : _scanReceipt,
                    tooltip: '拍照識別收據（免費）',
                    icon: _scanBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.camera_alt),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '📷 拍照識別收據 — 完全免費，無需網絡',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 16),

              // Category dropdown
              DropdownButtonFormField<ExpenseCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: '類別'),
                items: ExpenseCategory.values
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.label),
                      ),
                    )
                    .toList(),
                onChanged: (c) {
                  if (c != null) setState(() => _category = c);
                },
              ),
              const SizedBox(height: 16),

              // Note
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '備註',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),

              // Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('日期'),
                subtitle: Text(DateFormat.yMMMd('zh_HK').format(_date)),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: _pickDate,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant),
                ),
              ),
              const SizedBox(height: 16),

              // AI Categorize button — gated by IAP
              if (aiBlocked)
                OutlinedButton.icon(
                  onPressed: _showAiProPrompt,
                  icon: const Icon(Icons.lock),
                  label: const Text('🔒 AI 自動分類（AI Pro）'),
                )
              else
                OutlinedButton.icon(
                  onPressed: _aiBusy ? null : _runAiCategorize,
                  icon: _aiBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(_aiBusy ? 'AI 分類中…' : '✨ AI 自動分類'),
                ),
              const SizedBox(height: 8),
              Text(
                aiBlocked
                    ? '訂閱 AI Pro 解鎖 AI 分類、月報洞察、雲端備份'
                    : '透過 AI 分析金額和備註，自動推薦最合適的分類',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 24),

              // Submit
              FilledButton(
                onPressed: _submit,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('儲存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountCandidateSheet extends StatelessWidget {
  const _AmountCandidateSheet({
    required this.candidates,
    required this.onCustomInput,
  });

  final List<AmountCandidate> candidates;
  final VoidCallback onCustomInput;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final likelyTotals =
        candidates.where((c) => c.isLikelyTotal && !c.isSuspicious).toList();
    final others =
        candidates.where((c) => !c.isLikelyTotal || c.isSuspicious).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '請確認這筆金額',
                style: theme.textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (likelyTotals.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '推薦（合計行）',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    ...likelyTotals.map((c) => _candidateTile(context, c)),
                  ],
                  if (others.isNotEmpty) ...[
                    if (likelyTotals.isNotEmpty)
                      const Divider(height: 24, indent: 16, endIndent: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '其他金額',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                    ...others.map((c) => _candidateTile(context, c)),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.edit_outlined,
                color: theme.colorScheme.outline,
              ),
              title: const Text('手動輸入金額…'),
              onTap: onCustomInput,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _candidateTile(BuildContext context, AmountCandidate c) {
    final theme = Theme.of(context);
    final warningColor = theme.colorScheme.error;

    return ListTile(
      leading: Icon(
        c.isSuspicious
            ? Icons.warning_amber_rounded
            : c.isLikelyTotal
                ? Icons.recommend
                : Icons.payments_outlined,
        color: c.isSuspicious
            ? warningColor
            : c.isLikelyTotal
                ? theme.colorScheme.primary
                : null,
      ),
      title: Text(
        c.raw.isNotEmpty ? c.raw : c.value,
        style: TextStyle(
          fontWeight: c.isLikelyTotal ? FontWeight.w600 : FontWeight.normal,
          color: c.isSuspicious ? warningColor : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HK\$ ${c.value}'),
          if (c.context != null && c.context != c.raw)
            Text(
              c.context!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          if (c.isSuspicious)
            Text(
              '疑似日期，不推薦',
              style: theme.textTheme.bodySmall?.copyWith(color: warningColor),
            ),
        ],
      ),
      onTap: () => Navigator.pop(context, c),
    );
  }
}
