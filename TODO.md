# Expense Tracker — TODO

_最后更新：2026-05-20_

**架构文档：** [docs/SYNC-AND-IAP-DESIGN.md](docs/SYNC-AND-IAP-DESIGN.md)（Supabase 匿名登录、IAP、迁移、Workshop 分层）

**培训 Agent handoff：** [docs/WORKSHOP-HANDOFF.md](docs/WORKSHOP-HANDOFF.md)

---

## Supabase 匿名登录 + IAP + 云同步（待做）

**已定方案：** 无邮箱注册；启动 `signInAnonymously()`；IAP 后绑定 Pro；换机「恢复购买」+ 数据迁移。详见 [docs/SYNC-AND-IAP-DESIGN.md](docs/SYNC-AND-IAP-DESIGN.md)。

### 后端（Supabase + Vercel）

- [x] SQL 迁移脚本：`supabase/migrations/001_sync_schema.sql`（需在 Dashboard 执行）
- [ ] 创建 Supabase 项目并跑迁移
- [ ] Vercel：收据校验接口（Apple / Google），写入 `profiles.is_pro`、`iap_original_tx_id`
- [x] Vercel：`/api/me`、`/api/dev-activate-pro`；LLM 校验 JWT + Pro（未配 Supabase 时跳过）
- [ ] （阶段 2）恢复购买 + 按 `iap_original_tx_id` 合并旧 `user_id` 的 `expenses` 到新 `user_id`

### Flutter 数据层

- [x] 集成 `supabase_flutter`；启动时 `signInAnonymously()`
- [x] `ExpenseRepository` + `SyncService`：SQLite 为主；Pro/演示模式云同步（上行 + 拉取）
- [x] `SubscriptionService`：`profiles.is_pro` + 演示模式；`dev-activate-pro`（debug）
- [ ] 真 IAP 收据 API 替换开发激活

### UI / 产品

- [ ] IAP 购买流程（替换「开发中…」占位）
- [x] 设置页：云同步状态、「立即同步」、开发激活 Pro
- [ ] 「恢复购买」入口（阶段 2）
- [ ] （可选）迁移进度提示

### Workshop / 文档

- [ ] Tier B 演示脚本：匿名登录 + Dashboard 看到一条 expense
- [ ] Cheatsheet：真 IAP、RLS、迁移、开发者账号对比（见 SYNC 文档 FAQ）
- [x] Agent handoff 索引：[docs/WORKSHOP-HANDOFF.md](docs/WORKSHOP-HANDOFF.md)（待文档 Agent 展开 Tier A/B 脚本）

---

## OCR：金额候选置信度提示（待做）

**背景：** Apple Vision（iOS）与 ML Kit（Android）在识别阶段均可提供 line/element 级 `confidence`（0.0–1.0），但当前 App 未透传、未在 UI 展示。误读（如的士小票 `62.60` → `52.60`）时模型仍可能给出较高置信度，因此该提示仅供用户参考，不能替代人工确认。

**目标：** 在 OCR 金额候选列表中，于每个选项后标注 **「很确定」** / **「不太确定」**，帮助用户优先选择更可信的候选。

### 数据层

- [ ] `AmountCandidate` 增加 `double? confidence`（0.0–1.0，对应识别行/块）
- [ ] **Android（Kotlin）：** 从 ML Kit `Text.Line`（或 `Text.Element`）取 `confidence`，在 `extractAmountCandidates` 时绑定到含该金额的 line
- [ ] **iOS（Swift）：** 从 `VNRecognizedText.confidence` 绑定到对应行（当前仅 `topCandidates(1)`，需保留每行 confidence）
- [ ] **Dart：** `parseAmountCandidates` / `AmountCandidate.fromMap` 解析并传递 `confidence`
- [ ] MethodChannel 返回的 candidate map 增加 `"confidence"` 字段

### UI 层（`add_expense_screen.dart` → `_AmountCandidateSheet`）

- [ ] 根据阈值显示文案（阈值可后续调参，建议初值）：
  - `confidence >= 0.8` → **很确定**
  - `confidence < 0.8` 或 `null` → **不太确定**
- [ ] 样式：次要标签（`labelSmall` / `outline` 色），不打断主信息（金额、`raw`、context）
- [ ] 排序：在现有 `isLikelyTotal` / `isSuspicious` 逻辑之后，可将高 confidence 略靠前（可选）

### 文档与测试

- [ ] 更新 `docs/OCR-V2-DESIGN.md`：与 `AmountCandidate.confidence` 对齐
- [ ] 真机/模拟器验证：`IMG_0060`（的士小票）、`IMG_0064`（支付截图）两图在双端均有 confidence 且 UI 展示正确
- [ ] 注明 iOS `accurate` 模式下 confidence 可能仅 0.3 / 0.5 / 1.0 等离散值，阈值需按实测调整

### 参考

- iOS：`VNRecognizedText.confidence`
- Android：ML Kit `Text.Line.getConfidence()` / `Text.Element.getConfidence()`
- 设计原则（已有）：OCR 负责「看见」，用户负责「判断」—— 置信度标签是辅助，不是自动选中
