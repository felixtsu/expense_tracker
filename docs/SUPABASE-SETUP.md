# Supabase 项目配置（云同步）

## 1. 创建项目

1. [supabase.com](https://supabase.com) → New project  
2. 记下 **Project URL** 与 **anon public key**（Settings → API）

## 2. 启用匿名登录

Authentication → Providers → **Anonymous sign-ins** → Enable

## 3. 执行迁移

SQL Editor → 粘贴并运行 [`supabase/migrations/001_sync_schema.sql`](../supabase/migrations/001_sync_schema.sql)

验证：`profiles`、`expenses` 表存在，RLS 已启用。

## 4. Flutter 构建注入

推荐：复制根目录 [`.env.example`](../.env.example) → `.env.local`，填 `SUPABASE_URL`、`SUPABASE_ANON_KEY`、`API_BASE_URL`，然后：

```bash
./scripts/run-ios.sh
```

脚本会自动 `source .env.local` 并传入 `--dart-define`。

未配置时 App 仍可本地记账；云同步与 JWT 鉴权 API 不可用。

## 5. Vercel 环境变量

| 变量 | 说明 |
|------|------|
| `SUPABASE_URL` | 同 Flutter |
| `SUPABASE_SERVICE_ROLE_KEY` | **仅服务端**，用于 JWT 校验与 `is_pro` 写入 |
| `DEV_PRO_SECRET` | Workshop 开发激活 Pro（可选） |

详见 [API-DEPLOY.md](API-DEPLOY.md)。鉴权流程与 Flutter 对照见 [API-AUTH.md](API-AUTH.md)。

## 6. 手动验证（Tier B）

1. App 启动 → 自动 `signInAnonymously()`  
2. 设置 → 开启 AI 演示模式（或 dev 激活 Pro）→ 记一笔  
3. Supabase Dashboard → Table Editor → `expenses` 出现对应行，`user_id` = 当前匿名用户
