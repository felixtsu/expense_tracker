# 云同步与 IAP 设计 — Supabase 匿名登录 + 购买迁移

_最后更新：2026-05-20_

## 产品原则

- **不要求用户注册**（无邮箱/手机号登录 UI）
- **购买即可用**：免费档本地能力；付费档解锁 AI + 云同步等
- **双端一致**：iOS / Android 共用同一套后端，**不依赖 iCloud**（避免仅 iOS 生态 + Apple 开发者账号门槛）

---

## 架构结论（已定）

采用 **Supabase Anonymous Auth** 作为「无感用户身份」，IAP 成功后绑定 **付费权益（entitlement）**，换机通过 **恢复购买** 找回权益与数据迁移能力。

```text
首次打开 App
    → signInAnonymously() 得到 user.id（用户无感，不算「注册」）
    → 本地 SQLite 记账（离线可用）
    → 可选：expenses 同步到 Supabase（按 auth.uid() + RLS）

用户购买 AI Pro（IAP）
    → 收据发到 Vercel / Edge Function 校验
    → profiles 表：该 user.id 标记 is_pro = true
    → 解锁：云同步、LLM 分类、月报洞察等

换机 / 重装
    → 新设备再次 signInAnonymously()（新的匿名 user.id）
    → 用户点「恢复购买」
    → 服务端用收据找到原 entitlement / 旧 user.id
    → 迁移：合并 expenses 或 link 身份（见下文「数据迁移」）
```

**一句话：** 免费用户是「匿名云账号」；付费是把该账号标成 Pro；换机靠 IAP 恢复，不靠邮箱注册。

---

## 为什么不用「邮箱注册」仍可用 Supabase

| 误解 | 实际情况 |
|------|----------|
| 用 Supabase 就要做登录页 | 否。Anonymous Auth 在后台创建 `auth.users` 行，用户从未填表 |
| 没有 user id 无法做 RLS | 匿名登录后 `auth.uid()` 即稳定 UUID（在同一会话/用户生命周期内） |
| 不买 Apple $99 不能做云 | 否。Supabase 免费项目 + 模拟器/真机 debug 即可开发和演示 |

`auth.users` 里的匿名用户是**实现细节**，不是产品上的「注册」。

---

## 身份与唯一 ID

### 推荐：Supabase Anonymous Auth（主键）

- 首次启动调用 `signInAnonymously()`
- 使用 `session.user.id` 作为全链路 `user_id`
- Session 持久化在设备（Supabase Flutter SDK 自动处理刷新）

### 不推荐单独依赖（仅作补充说明）

| 方式 | 问题 |
|------|------|
| 仅 `SharedPreferences` 自生成 UUID | 重装易丢；RLS 难和安全绑定 |
| 仅 iOS `identifierForVendor` / Android `ANDROID_ID` | 跨平台不一致；恢复出厂/卸光 App 会变 |
| 仅设备 ID 写表 + anon key 裸连 | 易伪造 `device_id`，易串数据 |

### IAP 后的「商业身份」

- 收据校验通过后，在服务端写入 **`entitlement_id`** 或绑定 **`original_transaction_id`**（Apple）/ **`purchaseToken`**（Google）
- `profiles` 表：`user_id` ↔ `is_pro` ↔ `iap_original_transaction_id`
- **恢复购买**：用收据在服务端查回同一 entitlement，再决定合并到哪条 `user_id`

---

## 数据模型（概念）

```text
auth.users              -- Supabase 管理（含匿名用户）

profiles
  user_id               -- PK, FK → auth.users
  is_pro                -- bool
  iap_product_id        -- string, nullable
  iap_original_tx_id    -- string, nullable（恢复购买关键）
  created_at / updated_at

expenses
  id                    -- uuid 或 bigint
  user_id               -- FK → auth.users, RLS 隔离
  amount, category, note, date, ...
  updated_at            -- 同步冲突用
```

### RLS 策略（原则）

```sql
-- 示例：用户只能读写自己的行
create policy "expenses_select_own" on expenses
  for select using (auth.uid() = user_id);

create policy "expenses_insert_own" on expenses
  for insert with check (auth.uid() = user_id);
```

**禁止：** 仅靠 App 内拼 `device_id` + 公开 anon key 访问全表。

---

## 与现有 App 的衔接

| 现有模块 | 当前 | 目标 |
|----------|------|------|
| `ExpenseLocalDataSource` / SQLite | 本地主存储 | 保留；离线优先，Pro 开启双向/上行同步 |
| `SubscriptionService` | SharedPreferences + **AI 演示模式** | IAP 校验后写 `profiles.is_pro`；演示模式保留给 Workshop |
| `ApiConfig` + Vercel | LLM 分类 / 月报洞察 | 请求带 Supabase JWT 或 `user_id`，服务端校验 Pro |
| IAP UI | 「IAP 购买流程开发中…」 | StoreKit 2 / Play Billing + 收据校验 API |
| OCR | 免费、离线 | 不变，不依赖云账号 |

---

## IAP 与数据迁移（分阶段）

### 阶段 1：同设备购买（MVP）

1. 匿名登录已有 `user_id`
2. IAP 成功 → 收据 API 校验 → `profiles.is_pro = true`
3. **数据不迁移**——本来就在同一 `user_id` 下
4. 开启：云同步 + AI 配额

### 阶段 2：换机 / 重装（迁移）

新设备 `signInAnonymously()` 会得到**新** `user_id`。用户点 **恢复购买** 后：

| 策略 | 说明 | 复杂度 |
|------|------|--------|
| **A. 服务端合并** | 用 `iap_original_tx_id` 找到旧 `user_id`，把 `expenses` 复制/合并到新 `user_id` | 中 |
| **B. Supabase linkIdentity** | 匿名用户 link 到稳定 identity（若后续引入 Sign in with Apple 等） | 高 |
| **C. 仅恢复 Pro 不同步历史** | 只恢复权益，历史留在旧匿名账号 | 低（不推荐作终态） |

**推荐产品文案：** 「恢复购买将同步您之前的记账数据（如有）」—— 实现上优先 **A**。

---

## 免费 vs 付费能力矩阵

| 能力 | 免费 | AI Pro（IAP） |
|------|------|----------------|
| 本地记账 SQLite | ✅ | ✅ |
| OCR 拍照识别 | ✅ | ✅ |
| 导出 CSV | ✅ | ✅ |
| 云同步 Supabase | ❌ 或仅本地 | ✅ |
| AI 自动分类 | ❌ | ✅ |
| AI 月报洞察 | ❌ | ✅ |

与 `main.dart` 注释一致：*Free version: OCR only. AI categorization/insight require AI Pro subscription.*

---

## Workshop 分层（备课用）

与「同学未必有 Apple/Google 付费开发者账号」对齐：

### Tier A — 全班实操（无需付费开发者账号）

- 本地记账 + SQLite
- OCR（相册/模拟器）
- **LLM**：设置 → **AI 演示模式** → 分类 / 月报（已有 Vercel API）
- CSV 导出

### Tier B — 可选 / 讲师带领（免费注册 Supabase 项目即可）

- Dashboard 创建项目
- 演示 `signInAnonymously()` + 插入一条 `expenses`
- 说明 RLS：`auth.uid() = user_id`

### Tier C — 讲师 Demo + Cheatsheet（进阶）

- 真 IAP（StoreKit 2 / Play Billing）
- 收据校验、恢复购买、数据合并迁移
- iCloud / CloudKit（仅 iOS，非本方案主线）
- 上架：Apple Developer $99/年、Google Play Console $25 一次性

**云同步主线讲 Supabase，不讲 iCloud**—— 双端一致、无需 Apple 付费账号即可开发演示。

---

## 开发者账号说明（FAQ）

| 能力 | Apple 付费 $99 | Apple 免费 Personal Team | Google Play $25 |
|------|----------------|---------------------------|-----------------|
| 模拟器跑 App | ✅ | ✅ | N/A |
| Supabase + 匿名登录 + LLM | ✅ | ✅ | ✅ |
| 真机调试 | ✅ | ✅（证书约 7 天） | ✅ |
| 上架商店 | ✅ | ❌ | ✅ |
| iCloud CloudKit 生产环境 | ✅ | 开发环境受限 | N/A |

**结论：** Workshop 实操**不强制**购买付费开发者计划；IAP/上架放 Cheatsheet。

---

## 安全与密钥

- **Supabase anon key** 可进 App，但必须配 **RLS**
- **OpenAI / 服务角色 key** 仅放 Vercel 环境变量（与现 `ApiConfig` 一致）
- **IAP 共享密钥 / Google service account** 仅服务端
- 收据校验必须在服务端完成，不可仅信客户端

---

## 实现清单（待开发）

详见项目根目录 [TODO.md](../TODO.md) 中「Supabase 匿名登录 + IAP」章节。

---

## 相关文档

- [OCR-V2-DESIGN.md](OCR-V2-DESIGN.md) — 金额候选、AI Pro 计费思路
- [OCR-DEVELOPMENT.md](OCR-DEVELOPMENT.md) — OCR 平台实现与测试
- [../TESTING.md](../TESTING.md) — 测试与 AI 演示模式
- [../TODO.md](../TODO.md) — 待办跟踪
