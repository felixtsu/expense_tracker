const { chatCompletion } = require('./_lib/deepseek');
const { CATEGORIES, normalizeCategory } = require('./_lib/categories');
const { setCors, handleOptions, parseBody } = require('./_lib/http');
const { requirePro } = require('./_lib/supabase');

const SYSTEM = `你是香港用户的记账助手。根据消费金额和备注，从固定类别中选出最合适的一项。
固定类别（必须返回其中之一）：${CATEGORIES.join('、')}
只输出 JSON，格式：{"category":"类别名"}`;

module.exports = async function handler(req, res) {
  setCors(res);
  if (handleOptions(req, res)) return;

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const auth = await requirePro(req, res);
  if (auth === null) return;

  const body = parseBody(req);
  const amount = body?.amount ?? '';
  const note = body?.note ?? '';

  if (!amount && !note) {
    return res.status(400).json({ error: 'amount or note is required' });
  }

  try {
    const raw = await chatCompletion({
      system: SYSTEM,
      user: `金额/描述：${amount}\n备注：${note}`,
      jsonMode: true,
    });

    let category = '其他';
    try {
      const parsed = JSON.parse(raw);
      category = normalizeCategory(parsed.category);
    } catch {
      category = normalizeCategory(raw);
    }

    return res.status(200).json({ category });
  } catch (err) {
    console.error('[categorize]', err);
    return res.status(500).json({
      error: '分类服务暂时不可用',
      detail: err.message,
    });
  }
};
