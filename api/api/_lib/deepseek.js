const DEEPSEEK_BASE_URL =
  process.env.DEEPSEEK_BASE_URL || 'https://api.deepseek.com';

/**
 * Call DeepSeek chat completions (OpenAI-compatible).
 * @param {{ system: string, user: string, jsonMode?: boolean }} opts
 * @returns {Promise<string>}
 */
async function chatCompletion({ system, user, jsonMode = false }) {
  const apiKey = process.env.DEEPSEEK_API_KEY;
  if (!apiKey) {
    throw new Error('DEEPSEEK_API_KEY is not configured');
  }

  const model = process.env.DEEPSEEK_MODEL || 'deepseek-chat';
  const body = {
    model,
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: user },
    ],
    stream: false,
    temperature: 0.3,
  };

  if (jsonMode) {
    body.response_format = { type: 'json_object' };
  }

  const response = await fetch(`${DEEPSEEK_BASE_URL}/chat/completions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`DeepSeek API ${response.status}: ${text}`);
  }

  const data = await response.json();
  const content = data?.choices?.[0]?.message?.content;
  if (!content || typeof content !== 'string') {
    throw new Error('DeepSeek returned empty content');
  }
  return content.trim();
}

module.exports = { chatCompletion };
