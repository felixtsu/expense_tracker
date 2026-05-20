# Vercel API 部署（DeepSeek）

后端为 Vercel Serverless Functions，LLM 使用 [DeepSeek API](https://platform.deepseek.com/api_keys)（OpenAI 兼容）。

## 端点

| 路径 | 方法 | 请求体 | 响应 |
|------|------|--------|------|
| `/api/categorize` | POST | `{ "amount": "62.6", "note": "的士" }` | `{ "category": "交通" }` |
| `/api/insight` | POST | `{ "year": 2026, "month": 5, "totals": { "餐饮": 12000 } }` | `{ "insight": "..." }` |

`totals` 的金额为**分**（整数），与 Flutter 客户端一致。

## 环境变量（Vercel 控制台）

| 变量 | 必填 | 说明 |
|------|------|------|
| `DEEPSEEK_API_KEY` | ✅ | [platform.deepseek.com](https://platform.deepseek.com/api_keys) 申请 |
| `DEEPSEEK_MODEL` | | 默认 `deepseek-chat` |
| `DEEPSEEK_BASE_URL` | | 默认 `https://api.deepseek.com` |

## 部署

```bash
cd /path/to/expense_tracker
npm i -g vercel   # 或 npx vercel
vercel login
vercel            # 首次：链接项目
vercel --prod     # 生产部署
```

在 Vercel → Project → Settings → Environment Variables 中配置 `DEEPSEEK_API_KEY`。

部署完成后记下 URL，例如 `https://expense-tracker-api-xxx.vercel.app`。

## Flutter 构建时注入 API URL

`lib/core/api_config.dart` 使用 `String.fromEnvironment('API_BASE_URL')`：

```bash
# Android release
API_BASE_URL=https://your-api.vercel.app ./scripts/build-apk.sh

# iOS release
API_BASE_URL=https://your-api.vercel.app ./scripts/build-ios.sh

# 开发 / 模拟器
API_BASE_URL=http://localhost:3000 ./scripts/run-ios.sh
vercel dev   # 另开终端
```

或直接：

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-api.vercel.app
```

## 本地调试 API

```bash
vercel dev
curl -X POST http://localhost:3000/api/categorize \
  -H 'Content-Type: application/json' \
  -d '{"amount":"45","note":"大家乐午餐"}'
```
