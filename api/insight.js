const { chatCompletion } = require('./_lib/deepseek');
const { setCors, handleOptions, parseBody } = require('./_lib/http');
const { requirePro } = require('./_lib/supabase');

const SYSTEM = `你是香港用戶的個人理財助手。根據用戶某月的分類支出總結，用香港繁體中文寫 2–3 句簡短洞察。
要求：語氣友好、具體、可執行；不要羅列數字表格；不要 markdown；總字數 80–150 字。`;

function formatTotals(totals) {
  if (!totals || typeof totals !== 'object') return '（無支出數據）';
  const lines = [];
  for (const [label, cents] of Object.entries(totals)) {
    const n = Number(cents);
    if (!Number.isFinite(n) || n <= 0) continue;
    const dollars = (n / 100).toFixed(2);
    lines.push(`${label}：HK$${dollars}`);
  }
  return lines.length ? lines.join('\n') : '（無支出數據）';
}

module.exports = async function handler(req, res) {
  setCors(res);
  if (handleOptions(req, res)) return;

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const auth = await requirePro(req, res);
  if (auth === null) return;

  const body = parseBody(req);
  const year = Number(body?.year);
  const month = Number(body?.month);
  const totals = body?.totals;

  if (!year || !month) {
    return res.status(400).json({ error: 'year and month are required' });
  }

  const summary = formatTotals(totals);

  try {
    const insight = await chatCompletion({
      system: SYSTEM,
      user: `${year}年${month}月支出總結（單位：港幣）：\n${summary}`,
      jsonMode: false,
    });

    return res.status(200).json({ insight });
  } catch (err) {
    console.error('[insight]', err);
    return res.status(500).json({
      error: '洞察服務暫時不可用',
      detail: err.message,
    });
  }
};
