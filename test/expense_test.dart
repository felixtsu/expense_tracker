import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker_app/domain/entities/expense.dart';
import 'package:expense_tracker_app/domain/entities/expense_category.dart';

void main() {
  group('ExpenseCategory', () {
    test('has 8 categories', () {
      expect(ExpenseCategory.values.length, 8);
    });

    test('each category has a Chinese label', () {
      for (final category in ExpenseCategory.values) {
        expect(category.label.isNotEmpty, true);
        expect(category.label.length, greaterThan(0));
      }
    });

    test('dining label is 餐饮', () {
      expect(ExpenseCategory.dining.label, '餐饮');
    });

    test('fromIndex clamps to valid range', () {
      expect(ExpenseCategory.fromIndex(-1), ExpenseCategory.values.first);
      expect(ExpenseCategory.fromIndex(100), ExpenseCategory.values.last);
    });

    test('storageIndex returns valid index', () {
      for (final category in ExpenseCategory.values) {
        expect(category.storageIndex, greaterThanOrEqualTo(0));
        expect(category.storageIndex, lessThan(8));
      }
    });
  });

  group('Expense', () {
    test('creates with required fields', () {
      final expense = Expense(
        amount: 25.5,
        category: ExpenseCategory.dining,
        note: '午餐',
        date: DateTime(2026, 5, 15),
      );

      expect(expense.amount, 25.5);
      expect(expense.category, ExpenseCategory.dining);
      expect(expense.note, '午餐');
      expect(expense.date, DateTime(2026, 5, 15));
      expect(expense.id, isNull);
    });

    test('copyWith creates new instance with updated fields', () {
      final original = Expense(
        id: 1,
        amount: 100.0,
        category: ExpenseCategory.shopping,
        note: '购物',
        date: DateTime(2026, 5, 1),
      );

      final updated = original.copyWith(amount: 200.0, note: '更新后的购物');

      expect(updated.id, 1);
      expect(updated.amount, 200.0);
      expect(updated.note, '更新后的购物');
      expect(updated.category, ExpenseCategory.shopping);
      expect(updated.date, DateTime(2026, 5, 1));
    });

    test('copyWith does not mutate original', () {
      final original = Expense(
        amount: 50.0,
        category: ExpenseCategory.transport,
        note: '打车',
        date: DateTime(2026, 5, 10),
      );

      original.copyWith(amount: 75.0);

      expect(original.amount, 50.0);
    });
  });
}
