# Workshop 培训材料 — Agent Handoff

_分支：`feature/supabase-sync` · 基线 tag：`v1.0.0-pre-sync` · 更新：2026-05-20_

**本文件用途：** 给「只读整理、产出培训材料」的 Agent 用。不要求改业务代码。

---

## 1. 你的任务

把本仓库的技术方案整理成 **Workshop 可讲、学员可跟做** 的材料，例如：

- 讲师脚本（按 Tier A / B / C 分段）
- 学员 Cheatsheet（命令、环境变量、常见问题）
- 架构图讲解顺序（可引用现有 mermaid）
- 演示 checklist（课前准备 / 课中 / 课后）

**不要：** 提交真实密钥、修改 `.env.local`、实现真 IAP（尚未做）。

---

## 2. 阅读顺序（建议）

| 顺序 | 文档 | 用途 |
|------|------|------|
| 1 | [SYNC-AND-IAP-DESIGN.md](SYNC-AND-IAP-DESIGN.md) | 产品原则、匿名登录、Pro、迁移、Workshop 分层 |
| 2 | [API-AUTH.md](API-AUTH.md) | Vercel + JWT + `is_pro` 鉴权（课堂可单独讲） |
| 3 | [SUPABASE-SETUP.md](SUPABASE-SETUP.md) | Supabase 项目、SQL 迁移、Flutter 注入 |
| 4 | [API-DEPLOY.md](API-DEPLOY.md) | Vercel 部署、环境变量 |
| 5 | [OCR-DEVELOPMENT.md](OCR-DEVELOPMENT.md) | OCR 双端、模拟器相册 |
| 6 | [OCR-V2-DESIGN.md](OCR-V2-DESIGN.md) | 金额候选、AI Pro 思路 |
| 7 | [../TESTING.md](../TESTING.md) | 手动测试步骤 |
| 8 | [../TODO.md](../TODO.md) | 已完成 / 待做 |

根目录 [`.env.example`](../.env.example) 汇总所有环境变量（学员 `cp .env.example .env.local`）。

---

## 3. Workshop 三层（已定，勿改方向）

### Tier A — 全班必做（无付费开发者账号）

- 本地 SQLite 记账、CSV 导出
- OCR：模拟器相册 [`test_resources/`](../test_resources/)（`IMG_0060` 的士、`IMG_0064` 支付）
- **AI 演示模式**（设置里开关）→ AI 分类 / 月报（Vercel + DeepSeek）
- **不讲** 云同步也可结课

**启动：**

```bash
cp .env.example .env.local   # 至少填 API_BASE_URL、DEEPSEEK 在 Vercel 上
./scripts/run-ios.sh         # 自动导入测试图到模拟器相册
```

### Tier B — 可选 / 讲师带领（免费 Supabase）

- Dashboard 开 **Anonymous sign-ins**
- 跑 [`supabase/migrations/001_sync_schema.sql`](../supabase/migrations/001_sync_schema.sql)
- `.env.local` 填 `SUPABASE_URL`、`SUPABASE_ANON_KEY`；Vercel 填 `SERVICE_ROLE`
- 演示：记一笔 → Dashboard 看到 `expenses`；设置里「立即同步」

### Tier C — Cheatsheet / 讲师 Demo（进阶，代码未做）

- 真 StoreKit / Play Billing
- 恢复购买 + `iap_original_tx_id` 数据合并
- 见 [TODO.md](../TODO.md) 阶段 2

---

## 4. 本分支已实现（可写进「当前能力」）

| 能力 | 状态 |
|------|------|
| Supabase 匿名登录（需 Dashboard 开启） | ✅ |
| SQLite 离线 + Pro/演示模式云同步 | ✅ |
| Vercel `/api/categorize`、`/api/insight` + JWT Pro 校验 | ✅ |
| `/api/me`、`/api/dev-activate-pro`（Workshop） | ✅ |
| `.env.example` + `load-env.sh` + 构建脚本 | ✅ |
| 设置：AI 演示、云同步、开发激活 Pro | ✅ |
| 真 IAP / 恢复购买 / 换机迁移 | ❌ 待做 |

**安全要点（培训必提）：**

- `SUPABASE_ANON_KEY` 可进 App，**必须**配 RLS
- `SUPABASE_SERVICE_ROLE_KEY`、`DEEPSEEK_API_KEY` **仅 Vercel**，脚本不会打进 Flutter
- 演示模式只绕过**客户端** Pro；服务端开鉴权后仍要 `is_pro` 或 mock 回退

---

## 5. 常见演示问题（FAQ 素材）

| 现象 | 原因 | 处理 |
|------|------|------|
| 红屏 Provider | 已修：用 `SyncScope` 传 SyncService | 拉最新 `feature/supabase-sync` |
| `Anonymous sign-ins are disabled` | Supabase 未开匿名登录 | Authentication → Providers |
| AI 403 | 未 Pro 且服务端已开鉴权 | 演示模式（mock）或 dev-activate-pro |
| 模拟器无相机 | 正常 | 从相册选；`import-test-receipts-ios.sh` |
| 相册无测试图 | 未导入 | `./scripts/import-test-receipts-ios.sh` |

---

## 6. 建议产出的文件（由文档 Agent 创建）

可在 `docs/workshop/` 下新增（命名可自定）：

- `TIER-A-SCRIPT.md` — 90 分钟基础课脚本
- `TIER-B-SUPABASE-DEMO.md` — 15 分钟云同步演示
- `CHEATSHEET.md` — 一页命令 + 环境变量
- `INSTRUCTOR-CHECKLIST.md` — 课前/课中检查项

完成后在 [TODO.md](../TODO.md) Workshop 小节打勾。

---

## 7. Git 参考

```bash
git checkout feature/supabase-sync
git log v1.0.0-pre-sync..HEAD    # 同步功能相对基线的提交
git tag -l 'v*'
```

本地 secrets：**`.env.local` 不在仓库**，讲师自备。
