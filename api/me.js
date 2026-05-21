const { setCors, handleOptions } = require('./_lib/http');
const { getUserFromToken } = require('./_lib/supabase');

module.exports = async function handler(req, res) {
  setCors(res);
  if (handleOptions(req, res)) return;

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const user = await getUserFromToken(req, res);
  if (user === null) return;

  return res.status(200).json({
    user_id: user.userId,
    is_pro: user.isPro,
  });
};
