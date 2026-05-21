import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api_config.dart';
import '../core/supabase_config.dart';

/// Manages IAP / Pro entitlement and AI quota.
/// [isDemoMode] bypasses checks for Workshop; server [isPro] from Supabase profiles.
class SubscriptionService {
  SubscriptionService._(this._prefs, {SupabaseClient? supabase})
      : _supabase = supabase;

  final SharedPreferences _prefs;
  final SupabaseClient? _supabase;

  static const _keyPro = 'is_pro_cached';
  static const _keyDemo = 'ai_demo_mode';
  static const _keyAiRemaining = 'ai_calls_remaining';

  static Future<SubscriptionService> create({SupabaseClient? supabase}) async {
    final prefs = await SharedPreferences.getInstance();
    final client = supabase ??
        (SupabaseConfig.isConfigured ? Supabase.instance.client : null);
    return SubscriptionService._(prefs, supabase: client);
  }

  bool get isDemoMode => _prefs.getBool(_keyDemo) ?? false;

  bool get isProCached => _prefs.getBool(_keyPro) ?? false;

  /// Pro from server cache, or demo mode.
  bool get isAiProActive => isDemoMode || isProCached;

  /// Cloud sync allowed when Pro (server or demo).
  bool get canUseCloudSync => isAiProActive && SupabaseConfig.isConfigured;

  int get aiCallsRemaining => _prefs.getInt(_keyAiRemaining) ?? 0;

  static const int kDailyLimit = 3;

  String? checkAiAccess() {
    if (isDemoMode) return null;
    if (!isAiProActive) return '请订阅 AI Pro 解锁此功能';
    if (aiCallsRemaining <= 0) return '今日 AI 调用次数已用完';
    return null;
  }

  Future<void> consumeAiCall() async {
    final remaining = aiCallsRemaining;
    await _prefs.setInt(_keyAiRemaining, remaining - 1);
  }

  Future<void> resetDailyQuota() async {
    await _prefs.setInt(_keyAiRemaining, kDailyLimit);
  }

  Future<void> enableDemoMode() async {
    await _prefs.setBool(_keyDemo, true);
    await _prefs.setBool(_keyPro, true);
    await _prefs.setInt(_keyAiRemaining, 999);
  }

  Future<void> disableDemoMode() async {
    await _prefs.setBool(_keyDemo, false);
    await _prefs.setBool(_keyPro, false);
    await _prefs.setInt(_keyAiRemaining, 0);
    await refreshEntitlement();
  }

  /// Load `profiles.is_pro` from Supabase (or Vercel /api/me fallback).
  Future<void> refreshEntitlement() async {
    if (isDemoMode) return;

    final client = _supabase;
    if (client != null) {
      try {
        final userId = client.auth.currentUser?.id;
        if (userId == null) {
          await _prefs.setBool(_keyPro, false);
          return;
        }
        final row = await client
            .from('profiles')
            .select('is_pro')
            .eq('user_id', userId)
            .maybeSingle();
        final isPro = row?['is_pro'] as bool? ?? false;
        await _prefs.setBool(_keyPro, isPro);
        if (isPro && aiCallsRemaining <= 0) {
          await resetDailyQuota();
        }
        return;
      } catch (e, st) {
        debugPrint('[Subscription] Supabase profile: $e\n$st');
      }
    }

    final token = client?.auth.currentSession?.accessToken;
    if (token == null) return;

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/me');
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        await _prefs.setBool(_keyPro, json['is_pro'] as bool? ?? false);
      }
    } catch (e, st) {
      debugPrint('[Subscription] /api/me: $e\n$st');
    }
  }

  /// Workshop / debug: server sets profiles.is_pro via DEV_PRO_SECRET.
  Future<bool> activateProForDev({required String secret}) async {
    final userId = _supabase?.auth.currentUser?.id;
    if (userId == null) return false;

    final uri = Uri.parse('${ApiConfig.baseUrl}/api/dev-activate-pro');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'secret': secret, 'user_id': userId}),
    );
    if (response.statusCode != 200) {
      debugPrint('[Subscription] dev-activate: ${response.statusCode} ${response.body}');
      return false;
    }
    await _prefs.setBool(_keyPro, true);
    await resetDailyQuota();
    return true;
  }
}
