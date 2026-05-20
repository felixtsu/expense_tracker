const CATEGORIES = [
  '餐饮',
  '交通',
  '购物',
  '居住',
  '医疗',
  '教育',
  '娱乐',
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
