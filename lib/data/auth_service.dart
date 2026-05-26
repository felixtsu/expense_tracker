import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';

/// Ensures an anonymous Supabase session (no login UI).
class AuthService {
  AuthService({SupabaseClient? client})
      : _client = client ??
            (SupabaseConfig.isConfigured ? Supabase.instance.client : null);

  final SupabaseClient? _client;

  bool get isAvailable => _client != null;

  String? get userId => _client?.auth.currentUser?.id;

  String? get accessToken => _client?.auth.currentSession?.accessToken;

  /// Returns existing session or signs in anonymously.
  Future<String?> ensureAnonymousSession() async {
    final client = _client;
    if (client == null) return null;

    try {
      final session = client.auth.currentSession;
      if (session != null) {
        final refreshed = await client.auth.refreshSession();
        return refreshed.session?.user.id ?? session.user.id;
      }
      final response = await client.auth.signInAnonymously();
      return response.user?.id;
    } catch (e, st) {
      debugPrint('[AuthService] ensureAnonymousSession failed: $e\n$st');
      return null;
    }
  }
}
