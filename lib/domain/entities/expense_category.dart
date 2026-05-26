/// Fixed categories for the expense tracker (Chinese labels + emoji).
enum ExpenseCategory {
  dining,
  transport,
  shopping,
  housing,
  medical,
  education,
  entertainment,
  other;

  String get emoji => switch (this) {
        ExpenseCategory.dining => '🍜',
        ExpenseCategory.transport => '🚕',
        ExpenseCategory.shopping => '🛒',
        ExpenseCategory.housing => '🏠',
        ExpenseCategory.medical => '💊',
        ExpenseCategory.education => '📚',
        ExpenseCategory.entertainment => '🎬',
        ExpenseCategory.other => '📌',
      };

  String get label => switch (this) {
        ExpenseCategory.dining => '餐飲',
        ExpenseCategory.transport => '交通',
        ExpenseCategory.shopping => '購物',
        ExpenseCategory.housing => '居住',
        ExpenseCategory.medical => '醫療',
        ExpenseCategory.education => '教育',
        ExpenseCategory.entertainment => '娛樂',
        ExpenseCategory.other => '其他',
      };

  static ExpenseCategory fromIndex(int index) {
    final i = index.clamp(0, ExpenseCategory.values.length - 1);
    return ExpenseCategory.values[i];
  }

  int get storageIndex => ExpenseCategory.values.indexOf(this);
}
