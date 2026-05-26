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
      version: 2,
      onCreate: (db, version) async {
        await _createV2(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE $_table ADD COLUMN remote_id TEXT",
          );
          await db.execute(
            "ALTER TABLE $_table ADD COLUMN updated_at TEXT",
          );
          await db.execute(
            "ALTER TABLE $_table ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'pending'",
          );
          await db.execute(
            "UPDATE $_table SET updated_at = date, sync_status = 'pending' WHERE updated_at IS NULL",
          );
        }
      },
    );
  }

  static Future<void> _createV2(Database db) async {
    await db.execute('''
CREATE TABLE $_table (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  remote_id TEXT,
  amount REAL NOT NULL,
  category_index INTEGER NOT NULL,
  note TEXT NOT NULL,
  date TEXT NOT NULL,
  updated_at TEXT,
  sync_status TEXT NOT NULL DEFAULT 'pending'
)
''');
  }

  static String defaultDbFilePath(String databasesPath) {
    return p.join(databasesPath, 'expense_tracker.db');
  }

  Future<List<Expense>> getAllOrdered() async {
    final rows = await _db.query(_table, orderBy: 'date DESC, id DESC');
    return rows.map(_fromRow).toList();
  }

  Future<List<Expense>> getPendingSync() async {
    final rows = await _db.query(
      _table,
      where: "sync_status = ? OR remote_id IS NULL",
      whereArgs: ['pending'],
      orderBy: 'id ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<Expense?> findByRemoteId(String remoteId) async {
    final rows = await _db.query(
      _table,
      where: 'remote_id = ?',
      whereArgs: [remoteId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<int> insert(Expense expense) async {
    return _db.insert(_table, _toRow(expense));
  }

  Future<void> insertFromRemote(Expense expense) async {
    await _db.insert(
        _table, _toRow(expense.copyWith(syncStatus: ExpenseSyncStatus.synced)));
  }

  Future<void> updateFromRemote(Expense expense) async {
    if (expense.id == null) return;
    await _db.update(
      _table,
      _toRow(expense.copyWith(syncStatus: ExpenseSyncStatus.synced)),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<void> markSynced({
    required int localId,
    required String remoteId,
    required DateTime updatedAt,
  }) async {
    await _db.update(
      _table,
      {
        'remote_id': remoteId,
        'updated_at': updatedAt.toIso8601String(),
        'sync_status': 'synced',
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
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
    final updated = e.updatedAt ?? e.date;
    return {
      if (e.id != null) 'id': e.id,
      if (e.remoteId != null) 'remote_id': e.remoteId,
      'amount': e.amount,
      'category_index': e.category.storageIndex,
      'note': e.note,
      'date': e.date.toIso8601String(),
      'updated_at': updated.toIso8601String(),
      'sync_status':
          e.syncStatus == ExpenseSyncStatus.synced ? 'synced' : 'pending',
    };
  }

  Expense _fromRow(Map<String, Object?> row) {
    final syncRaw = row['sync_status'] as String? ?? 'pending';
    return Expense(
      id: row['id'] as int?,
      remoteId: row['remote_id'] as String?,
      amount: (row['amount'] as num).toDouble(),
      category: ExpenseCategory.fromIndex(row['category_index'] as int),
      note: row['note'] as String? ?? '',
      date: DateTime.parse(row['date'] as String),
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
      syncStatus: syncRaw == 'synced'
          ? ExpenseSyncStatus.synced
          : ExpenseSyncStatus.pending,
    );
  }
}
