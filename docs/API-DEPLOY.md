# Vercel API 部署（DeepSeek）

后端为 Vercel Serverless Functions，LLM 使用 [DeepSeek API](https://platform.deepseek.com/api_keys)（OpenAI 兼容）。

**鉴权与双端模型（课堂用）** → 见 [API-AUTH.md](API-AUTH.md)。

## 端点

| 路径 | 方法 | 鉴权 | 说明 |
|------|------|------|------|
| `/api/categorize` | POST | Bearer JWT + Pro* | `{ "amount", "note" }` → `{ "category" }` |
| `/api/insight` | POST | Bearer JWT + Pro* | 月报洞察 |
| `/api/me` | GET | Bearer JWT | `{ "user_id", "is_pro" }` |
| `/api/dev-activate-pro` | POST | `DEV_PRO_SECRET` + `user_id` | Workshop 激活 Pro |

\* 若未配置 `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY`，AI 接口不校验（兼容旧部署）。

`totals` 的金额为**分**（整数），与 Flutter 客户端一致。

## 环境变量模板

仓库根目录 [`.env.example`](../.env.example) 汇总所有变量。本地：

```bash
cp .env.example .env.local
# 编辑 .env.local 后：./scripts/run-ios.sh 或 vercel dev
```

将 `.env.local` 里 **Vercel / vercel dev** 段的变量复制到 Vercel 控制台（不要提交 `.env.local`）。

## 环境变量（Vercel 控制台）

| 变量 | 必填 | 说明 |
|------|------|------|
| `DEEPSEEK_API_KEY` | ✅ | [platform.deepseek.com](https://platform.deepseek.com/api_keys) 申请 |
| `SUPABASE_URL` | 云同步 / 鉴权 | 与 Flutter 相同 |
| `SUPABASE_SERVICE_ROLE_KEY` | 云同步 / 鉴权 | **仅服务端** |
| `DEV_PRO_SECRET` | | Workshop 开发激活 Pro |
| `DEEPSEEK_MODEL` | | 默认 `deepseek-chat` |
| `DEEPSEEK_BASE_URL` | | 默认 `https://api.deepseek.com` |

Supabase 表与 RLS 见 [SUPABASE-SETUP.md](SUPABASE-SETUP.md)。

## 部署

```bash
cd /path/to/expense_tracker
npm install       # @supabase/supabase-js
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
