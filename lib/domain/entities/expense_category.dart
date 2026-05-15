/// Fixed categories for the expense tracker (Chinese labels).
enum ExpenseCategory {
  dining,
  transport,
  shopping,
  housing,
  medical,
  education,
  entertainment,
  other;

  String get label => switch (this) {
        ExpenseCategory.dining => '餐饮',
        ExpenseCategory.transport => '交通',
        ExpenseCategory.shopping => '购物',
        ExpenseCategory.housing => '居住',
        ExpenseCategory.medical => '医疗',
        ExpenseCategory.education => '教育',
        ExpenseCategory.entertainment => '娱乐',
        ExpenseCategory.other => '其他',
      };

  static ExpenseCategory fromIndex(int index) {
    final i = index.clamp(0, ExpenseCategory.values.length - 1);
    return ExpenseCategory.values[i];
  }

  int get storageIndex => ExpenseCategory.values.indexOf(this);
}
