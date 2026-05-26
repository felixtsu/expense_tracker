import 'expense_category.dart';

/// Local sync state for cloud upload.
enum ExpenseSyncStatus { pending, synced }

class Expense {
  const Expense({
    this.id,
    this.remoteId,
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
    this.updatedAt,
    this.syncStatus = ExpenseSyncStatus.pending,
  });

  final int? id;

  /// Supabase `expenses.id` (uuid).
  final String? remoteId;
  final double amount;
  final ExpenseCategory category;
  final String note;
  final DateTime date;
  final DateTime? updatedAt;
  final ExpenseSyncStatus syncStatus;

  Expense copyWith({
    int? id,
    String? remoteId,
    double? amount,
    ExpenseCategory? category,
    String? note,
    DateTime? date,
    DateTime? updatedAt,
    ExpenseSyncStatus? syncStatus,
  }) {
    return Expense(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      note: note ?? this.note,
      date: date ?? this.date,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
