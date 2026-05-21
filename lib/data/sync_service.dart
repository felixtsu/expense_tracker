import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/expense.dart';
import 'datasources/expense_local_data_source.dart';
import 'datasources/expense_remote_data_source.dart';
import 'subscription_service.dart';

enum SyncState { idle, syncing, error }

/// Uploads pending local rows and pulls remote changes for Pro / demo users.
class SyncService extends ChangeNotifier {
  SyncService({
    required ExpenseLocalDataSource local,
    required ExpenseRemoteDataSource remote,
    required SubscriptionService subscription,
    required SharedPreferences prefs,
  })  : _local = local,
        _remote = remote,
        _subscription = subscription,
        _prefs = prefs;

  final ExpenseLocalDataSource _local;
  final ExpenseRemoteDataSource _remote;
  final SubscriptionService _subscription;
  final SharedPreferences _prefs;

  static const _lastSyncKey = 'last_sync_at';

  SyncState _state = SyncState.idle;
  String? _lastError;

  SyncState get state => _state;
  String? get lastError => _lastError;

  bool get canSync => _subscription.canUseCloudSync;

  Future<void> syncNow({VoidCallback? onDataChanged}) async {
    if (!canSync) return;

    _state = SyncState.syncing;
    _lastError = null;
    notifyListeners();

    try {
      await _subscription.refreshEntitlement();
      if (!_subscription.canUseCloudSync) return;

      await _pushPending();
      await _pullRemote();
      onDataChanged?.call();
      _state = SyncState.idle;
    } catch (e, st) {
      debugPrint('[SyncService] syncNow failed: $e\n$st');
      _lastError = e.toString();
      _state = SyncState.error;
    } finally {
      notifyListeners();
    }
  }

  Future<void> pushOne(Expense expense, {VoidCallback? onDataChanged}) async {
    if (!canSync || expense.id == null) return;
    if (expense.syncStatus == ExpenseSyncStatus.synced &&
        expense.remoteId != null) {
      return;
    }

    try {
      final remoteId = await _remote.upsertExpense(expense);
      await _local.markSynced(
        localId: expense.id!,
        remoteId: remoteId,
        updatedAt: DateTime.now(),
      );
      onDataChanged?.call();
    } catch (e, st) {
      debugPrint('[SyncService] pushOne failed: $e\n$st');
    }
  }

  Future<void> _pushPending() async {
    final pending = await _local.getPendingSync();
    for (final expense in pending) {
      if (expense.id == null) continue;
      final remoteId = await _remote.upsertExpense(expense);
      await _local.markSynced(
        localId: expense.id!,
        remoteId: remoteId,
        updatedAt: DateTime.now(),
      );
    }
  }

  Future<void> _pullRemote() async {
    final sinceRaw = _prefs.getString(_lastSyncKey);
    final since =
        sinceRaw != null ? DateTime.tryParse(sinceRaw)?.toUtc() : null;

    final remoteList = await _remote.fetchExpensesSince(since);
    for (final remote in remoteList) {
      final remoteId = remote.remoteId;
      if (remoteId == null) continue;

      final existing = await _local.findByRemoteId(remoteId);
      if (existing == null) {
        await _local.insertFromRemote(remote);
      } else {
        final remoteUpdated = remote.updatedAt ?? remote.date;
        final localUpdated = existing.updatedAt ?? existing.date;
        if (remoteUpdated.isAfter(localUpdated)) {
          await _local.updateFromRemote(
            remote.copyWith(id: existing.id),
          );
        }
      }
    }

    await _prefs.setString(_lastSyncKey, DateTime.now().toUtc().toIso8601String());
  }
}
