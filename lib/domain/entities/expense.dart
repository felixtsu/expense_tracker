import 'expense_category.dart';

class Expense {
  const Expense({
    this.id,
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
  });

  final int? id;
  final double amount;
  final ExpenseCategory category;
  final String note;
  final DateTime date;

  Expense copyWith({
    int? id,
    double? amount,
    ExpenseCategory? category,
    String? note,
    DateTime? date,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      note: note ?? this.note,
      date: date ?? this.date,
    );
  }
}
