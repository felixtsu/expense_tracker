import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';

const _table = 'expenses';

class ExpenseLocalDataSource {
  ExpenseLocalDataSource(this._db);

  final Database _db;

  static Future<Database> open(String dbPath) async {
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE $_table (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  amount REAL NOT NULL,
  category_index INTEGER NOT NULL,
  note TEXT NOT NULL,
  date TEXT NOT NULL
)
''');
      },
    );
  }

  static String defaultDbFilePath(String databasesPath) {
    return p.join(databasesPath, 'expense_tracker.db');
  }

  Future<List<Expense>> getAllOrdered() async {
    final rows = await _db.query(_table, orderBy: 'date DESC, id DESC');
    return rows.map(_fromRow).toList();
  }

  Future<void> insert(Expense expense) async {
    await _db.insert(_table, _toRow(expense));
  }

  Future<Map<ExpenseCategory, double>> monthlyTotalsByCategory(
    int year,
    int month,
  ) async {
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);
    final rows = await _db.rawQuery(
      '''
SELECT category_index, SUM(amount) as total
FROM $_table
WHERE date >= ? AND date < ?
GROUP BY category_index
''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final map = {for (final c in ExpenseCategory.values) c: 0.0};
    for (final row in rows) {
      final idx = row['category_index'] as int;
      final total = (row['total'] as num?)?.toDouble() ?? 0;
      map[ExpenseCategory.fromIndex(idx)] = total;
    }
    return map;
  }

  Map<String, Object?> _toRow(Expense e) {
    return {
      if (e.id != null) 'id': e.id,
      'amount': e.amount,
      'category_index': e.category.storageIndex,
      'note': e.note,
      'date': e.date.toIso8601String(),
    };
  }

  Expense _fromRow(Map<String, Object?> row) {
    return Expense(
      id: row['id'] as int?,
      amount: (row['amount'] as num).toDouble(),
      category: ExpenseCategory.fromIndex(row['category_index'] as int),
      note: row['note'] as String? ?? '',
      date: DateTime.parse(row['date'] as String),
    );
  }
}
