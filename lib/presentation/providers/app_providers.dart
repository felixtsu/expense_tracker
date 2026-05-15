import 'package:flutter/foundation.dart';

import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';

/// Drives the expense list (SQLite-backed) and a [dataRevision] for report refresh.
class ExpenseListController extends ChangeNotifier {
  ExpenseListController(this._repository);

  final ExpenseRepository _repository;

  List<Expense> _expenses = [];
  bool _loading = true;
  Object? _error;
  int dataRevision = 0;

  List<Expense> get expenses => _expenses;
  bool get isLoading => _loading;
  Object? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _expenses = await _repository.getAll();
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> add(Expense expense) async {
    await _repository.insert(expense);
    dataRevision++;
    try {
      _expenses = await _repository.getAll();
    } catch (e) {
      _error = e;
    }
    notifyListeners();
  }
}

/// Bottom navigation index for [HomeShell].
class ShellNavigationController extends ChangeNotifier {
  int _index = 0;

  int get tabIndex => _index;

  void setTab(int index) {
    if (_index == index) return;
    _index = index;
    notifyListeners();
  }
}

/// Selected calendar month for the pie chart report.
class ReportMonthController extends ChangeNotifier {
  ReportMonthController() {
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
  }

  late DateTime _month;

  DateTime get month => _month;

  void prevMonth() {
    _month = DateTime(_month.year, _month.month - 1);
    notifyListeners();
  }

  void nextMonth() {
    _month = DateTime(_month.year, _month.month + 1);
    notifyListeners();
  }
}
