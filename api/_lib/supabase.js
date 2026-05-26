const { createClient } = require('@supabase/supabase-js');
const { getBearerToken } = require('./http');

function getServiceClient() {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) return null;
  return createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

function isAuthEnforced() {
  return Boolean(
    process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY,
  );
}

/**
 * Validates JWT and Pro entitlement when Supabase is configured.
 * @returns {Promise<{ userId: string, isPro: boolean } | null>} null if response already sent
 */
async function requirePro(req, res) {
  if (!isAuthEnforced()) {
    return { userId: null, isPro: true, skipped: true };
  }

  const token = getBearerToken(req);
  if (!token) {
    res.status(401).json({ error: '需要登入（Bearer JWT）' });
    return null;
  }

  const client = getServiceClient();
  const { data, error } = await client.auth.getUser(token);
  if (error || !data?.user) {
    res.status(401).json({ error: '無效或過期的登入' });
    return null;
  }

  const userId = data.user.id;
  const { data: profile, error: profileErr } = await client
    .from('profiles')
    .select('is_pro')
    .eq('user_id', userId)
    .maybeSingle();

  if (profileErr) {
    console.error('[auth] profile', profileErr);
    res.status(500).json({ error: '無法讀取訂閱狀態' });
    return null;
  }

  const isPro = profile?.is_pro === true;
  if (!isPro) {
    res.status(403).json({ error: '需要 AI Pro 訂閱' });
    return null;
  }

  return { userId, isPro: true, skipped: false };
}

/**
 * @returns {Promise<{ userId: string, isPro: boolean } | null>}
 */
async function getUserFromToken(req, res) {
  if (!isAuthEnforced()) {
    return { userId: null, isPro: false, skipped: true };
  }

  const token = getBearerToken(req);
  if (!token) {
    res.status(401).json({ error: '需要登入（Bearer JWT）' });
    return null;
  }

  const client = getServiceClient();
  const { data, error } = await client.auth.getUser(token);
  if (error || !data?.user) {
    res.status(401).json({ error: '無效或過期的登入' });
    return null;
  }

  const userId = data.user.id;
  const { data: profile } = await client
    .from('profiles')
    .select('is_pro')
    .eq('user_id', userId)
    .maybeSingle();

  return {
    userId,
    isPro: profile?.is_pro === true,
    skipped: false,
  };
}

module.exports = { getServiceClient, isAuthEnforced, requirePro, getUserFromToken };
