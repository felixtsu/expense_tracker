import 'package:shared_preferences/shared_preferences.dart';

/// Manages IAP subscription state for AI features.
/// Currently backed by SharedPreferences (temporary).
/// TODO: Replace with real IAP receipt validation + server-side entitlement check.
class SubscriptionService {
  SubscriptionService._(this._prefs);
  final SharedPreferences _prefs;

  static Future<SubscriptionService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SubscriptionService._(prefs);
  }

  /// Whether the user has an active AI Pro subscription.
  bool get isAiProActive {
    // TODO: check real IAP receipt / server entitlement
    return _prefs.getBool('ai_pro_active') ?? false;
  }

  /// Remaining AI calls in current billing period (0 = no quota left).
  int get aiCallsRemaining {
    return _prefs.getInt('ai_calls_remaining') ?? 0;
  }

  /// Daily limit for AI features.
  static const int kDailyLimit = 3;

  /// Demo mode: activates AI features without real IAP (for testing).
  bool get isDemoMode => _prefs.getBool('ai_demo_mode') ?? false;

  /// Check if AI features are accessible.
  /// Returns null if OK, or an error message if blocked.
  String? checkAiAccess() {
    if (isDemoMode) return null; // demo mode bypass
    if (!isAiProActive) return '请订阅 AI Pro 解锁此功能';
    if (aiCallsRemaining <= 0) return '今日 AI 调用次数已用完';
    return null;
  }

  /// Consume one AI call quota.
  Future<void> consumeAiCall() async {
    final remaining = aiCallsRemaining;
    await _prefs.setInt('ai_calls_remaining', remaining - 1);
  }

  /// Reset daily AI call quota (called by background job or app startup).
  Future<void> resetDailyQuota() async {
    await _prefs.setInt('ai_calls_remaining', kDailyLimit);
  }

  /// Activate demo mode (for testing without real IAP).
  Future<void> enableDemoMode() async {
    await _prefs.setBool('ai_demo_mode', true);
    await _prefs.setBool('ai_pro_active', true);
    await _prefs.setInt('ai_calls_remaining', 999);
  }

  /// Turn off demo mode and restore free-tier defaults.
  Future<void> disableDemoMode() async {
    await _prefs.setBool('ai_demo_mode', false);
    await _prefs.setBool('ai_pro_active', false);
    await _prefs.setInt('ai_calls_remaining', 0);
  }
}
