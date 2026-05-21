import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';

class UserProfile {
  const UserProfile({required this.userId, required this.isPro});

  final String userId;
  final bool isPro;
}

/// Supabase-backed expenses + profiles (RLS via user JWT).
class ExpenseRemoteDataSource {
  ExpenseRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<UserProfile?> fetchProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final row = await _client
          .from('profiles')
          .select('user_id, is_pro')
          .eq('user_id', userId)
          .maybeSingle();

      if (row == null) {
        return UserProfile(userId: userId, isPro: false);
      }
      return UserProfile(
        userId: row['user_id'] as String,
        isPro: row['is_pro'] as bool? ?? false,
      );
    } catch (e, st) {
      debugPrint('[ExpenseRemote] fetchProfile: $e\n$st');
      return null;
    }
  }

  Future<String> upsertExpense(Expense expense) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Not signed in to Supabase');
    }

    final now = DateTime.now().toUtc();
    final payload = {
      if (expense.remoteId != null) 'id': expense.remoteId,
      'user_id': userId,
      'amount': expense.amount,
      'category_index': expense.category.storageIndex,
      'note': expense.note,
      'date': expense.date.toUtc().toIso8601String(),
      'updated_at': (expense.updatedAt ?? now).toUtc().toIso8601String(),
    };

    final row = await _client
        .from('expenses')
        .upsert(payload)
        .select('id, updated_at')
        .single();

    return row['id'] as String;
  }

  Future<List<Expense>> fetchExpensesSince(DateTime? since) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    var query = _client
        .from('expenses')
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null);

    if (since != null) {
      query = query.gt('updated_at', since.toUtc().toIso8601String());
    }

    final rows = await query.order('updated_at', ascending: true);
    return (rows as List)
        .map((r) => _fromRemoteRow(r as Map<String, dynamic>))
        .toList();
  }

  Expense _fromRemoteRow(Map<String, dynamic> row) {
    final updatedRaw = row['updated_at'] as String?;
    final updatedAt =
        updatedRaw != null ? DateTime.parse(updatedRaw).toLocal() : null;
    final dateRaw = row['date'] as String;
    return Expense(
      remoteId: row['id'] as String,
      amount: (row['amount'] as num).toDouble(),
      category: ExpenseCategory.fromIndex(row['category_index'] as int),
      note: row['note'] as String? ?? '',
      date: DateTime.parse(dateRaw).toLocal(),
      updatedAt: updatedAt,
      syncStatus: ExpenseSyncStatus.synced,
    );
  }
}
