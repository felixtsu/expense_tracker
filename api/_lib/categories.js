const CATEGORIES = [
  '餐飲',
  '交通',
  '購物',
  '居住',
  '醫療',
  '教育',
  '娛樂',
  '其他',
];

const CATEGORY_SET = new Set(CATEGORIES);

function normalizeCategory(label) {
  if (!label || typeof label !== 'string') return '其他';
  const trimmed = label.trim();
  if (CATEGORY_SET.has(trimmed)) return trimmed;
  for (const c of CATEGORIES) {
    if (trimmed.includes(c)) return c;
  }
  return '其他';
}

module.exports = { CATEGORIES, CATEGORY_SET, normalizeCategory };
