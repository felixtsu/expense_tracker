const { chatCompletion } = require('./_lib/deepseek');
const { setCors, handleOptions, parseBody } = require('./_lib/http');

const SYSTEM = `你是香港用户的个人理财助手。根据用户某月的分类支出汇总，用简体中文写 2–3 句简短洞察。
要求：语气友好、具体、可执行；不要罗列数字表格；不要 markdown；总字数 80–150 字。`;

function formatTotals(totals) {
  if (!totals || typeof totals !== 'object') return '（无支出数据）';
  const lines = [];
  for (const [label, cents] of Object.entries(totals)) {
    const n = Number(cents);
    if (!Number.isFinite(n) || n <= 0) continue;
    const dollars = (n / 100).toFixed(2);
    lines.push(`${label}：HK$${dollars}`);
  }
  return lines.length ? lines.join('\n') : '（无支出数据）';
}

module.exports = async function handler(req, res) {
  setCors(res);
  if (handleOptions(req, res)) return;

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

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
      user: `${year}年${month}月支出汇总（单位：港币）：\n${summary}`,
      jsonMode: false,
    });

    return res.status(200).json({ insight });
  } catch (err) {
    console.error('[insight]', err);
    return res.status(500).json({
      error: '洞察服务暂时不可用',
      detail: err.message,
    });
  }
};
