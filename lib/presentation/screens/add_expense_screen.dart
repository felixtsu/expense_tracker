import 'package:flutter/material.dart';
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
    setState(() => _scanBusy = true);
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (xFile == null) return;

      final result = await _ocr.scan(xFile.path);
      if (result == null) {
        _showSnackBar('未能识别，请手动输入');
        return;
      }

      setState(() {
        if (result.amount != null && result.amount!.isNotEmpty) {
          _amountController.text = result.amount!;
        }
        if (result.merchant != null && result.merchant!.isNotEmpty) {
          _noteController.text = result.merchant!;
        }
      });

      final parts = <String>[];
      if (result.amount != null) parts.add('金额 ${result.amount}');
      if (result.merchant != null) parts.add('商户 ${result.merchant}');
      _showSnackBar('已识别：${parts.join('、')}');
    } catch (e) {
      _showSnackBar('拍照识别失败：$e');
    } finally {
      setState(() => _scanBusy = false);
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
        title: const Text('🔒 AI Pro 订阅'),
        content: const Text(
          'AI 自动分类是 AI Pro 功能。订阅后可解锁：\n'
          '• 无限次 AI 分类\n'
          '• AI 月报洞察\n'
          '• 云端数据备份\n\n'
          '订阅费用按实际 Token 用量计费。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('不了'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: open IAP purchase flow
              _showSnackBar('IAP 购买流程开发中…');
            },
            child: const Text('立即订阅'),
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
      if (mounted) _showSnackBar('AI 分类失败：$e');
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
      const SnackBar(content: Text('已保存')),
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
      appBar: AppBar(title: const Text('记一笔')),
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '金额',
                        prefixText: '¥ ',
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return '请输入金额';
                        final n = double.tryParse(t);
                        if (n == null || n <= 0) return '请输入有效正数';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    onPressed: _scanBusy ? null : _scanReceipt,
                    tooltip: '拍照识别收据（免费）',
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
                '📷 拍照识别收据 — 完全免费，无需网络',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 16),

              // Category dropdown
              DropdownButtonFormField<ExpenseCategory>(
                value: _category,
                decoration: const InputDecoration(labelText: '类别'),
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
                  labelText: '备注',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),

              // Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('日期'),
                subtitle: Text(DateFormat.yMMMd('zh_CN').format(_date)),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: _pickDate,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                ),
              ),
              const SizedBox(height: 16),

              // AI Categorize button — gated by IAP
              if (aiBlocked)
                OutlinedButton.icon(
                  onPressed: _showAiProPrompt,
                  icon: const Icon(Icons.lock),
                  label: const Text('🔒 AI 自动分类（AI Pro）'),
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
                  label: Text(_aiBusy ? 'AI 分类中…' : '✨ AI 自动分类'),
                ),
              const SizedBox(height: 8),
              Text(
                aiBlocked
                    ? '订阅 AI Pro 解锁 AI 分类、月报洞察、云端备份'
                    : '通过 AI 分析金额和备注，自动推荐最合适的分类',
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
                  child: Text('保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
