const { setCors, handleOptions, parseBody } = require('./_lib/http');
const { getServiceClient } = require('./_lib/supabase');

module.exports = async function handler(req, res) {
  setCors(res);
  if (handleOptions(req, res)) return;

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const secret = process.env.DEV_PRO_SECRET;
  if (!secret) {
    return res.status(503).json({ error: 'DEV_PRO_SECRET not configured' });
  }

  const body = parseBody(req);
  if (body?.secret !== secret) {
    return res.status(403).json({ error: 'Invalid secret' });
  }

  const userId = body?.user_id;
  if (!userId || typeof userId !== 'string') {
    return res.status(400).json({ error: 'user_id is required' });
  }

  const client = getServiceClient();
  if (!client) {
    return res.status(503).json({ error: 'Supabase not configured' });
  }

  const { error } = await client.from('profiles').upsert({
    user_id: userId,
    is_pro: true,
    updated_at: new Date().toISOString(),
  });

  if (error) {
    console.error('[dev-activate-pro]', error);
    return res.status(500).json({ error: error.message });
  }

  return res.status(200).json({ ok: true, user_id: userId, is_pro: true });
};
