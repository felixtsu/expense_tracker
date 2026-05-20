# OCR V2 — 候选提取 + 用户选择 + LLM 辅助（AI Pro）

_更新：2026-05-20_

## 设计原则

**不猜、不蒙、不强制。** OCR 负责「看见」，用户负责「判断」，LLM 负责「建议」。

---

## 1. 数据结构

### 1.1 新 OcrResult（所有平台统一）

```dart
/// 单个金额候选
class AmountCandidate {
  final String value;          // "47.40"
  final String raw;            // "HK$47.40"（原始 OCR 文本）
  final String? context;       // 邻近文字，如 "Total: HK$47.40"
  final bool isLikelyTotal;    // 是否含 total/总计 等关键词（UI 优先推荐）
  final bool isSuspicious;     // 是否疑似年份（1900~2100 且 .00）
}

/// OCR 结果
class OcrResult {
  final String rawText;
  final List<AmountCandidate> amountCandidates;  // 所有候选，按可信度排序
  final String? merchant;
}
```

### 1.2 接口变更

```dart
abstract class ExpenseOcrDataSource {
  /// 扫描收据，返回所有候选金额（不做过滤，保留上下文）
  Future<OcrResult?> scan(String imagePath);
}
```

---

## 2. 平台实现

### 2.1 Android（Kotlin）

**文件：** `android/app/src/main/kotlin/.../MainActivity.kt`

- `recognizeText` → 返回所有匹配金额，不做「选最大」
- 保留完整 `context`（金额所在行完整文字）
- `isLikelyTotal` = 该行含 total/总计/合计/金额/总额/实付/应付/小计
- `isSuspicious` = 值在 1900~2100 之间且小数部分为 .00

### 2.2 iOS（Swift）

**文件：** `ios/Runner/AppDelegate.swift`

- `extractAmountCandidates(from:)` → 返回数组，不是单个值
- Vision OCR 逐行处理，标注每行是否为 total 行
- 同样标注 suspicious

### 2.3 Dart 层（iOS fallback / Android）

**文件：** `lib/data/datasources/apple_vision_ocr_data_source.dart`

- 如果原生层返回的是 `amountCandidates`，直接透传
- 如果原生层只返回单个 `amount`，用 OCR raw text 反推候选列表

---

## 3. UI 流程

### 3.1 Free 用户（无 IAP）

```
用户点相机 → 选择图片
    ↓
OCR 扫描 → 底部弹窗展示候选
    ↓
┌──────────────────────────────┐
│ 📋  请确认这笔金额            │
│                              │
│  🔹 Total                     │  ← isLikelyTotal = true，置顶
│     HK$47.40                 │
│     "Total: HK$47.40"        │
│                              │
│  🔹 HK$ 前缀                  │
│     HK$44.00                 │
│     "HK$44.00"               │
│                              │
│  ⚠️ 疑似日期（不推荐）         │  ← isSuspicious = true
│     2024.00                  │
│     "DATE: 2024.00"          │
│                              │
│  ─── 或手动输入 ───           │
│  [ ____________ ]           │
└──────────────────────────────┘
    ↓ 用户点击 / 手动输入
金额填入 amountController
用户继续选分类、填备注 → 保存
```

### 3.2 AI Pro 用户（有 IAP）

```
用户完成金额选择（步骤同上）
    ↓
merchant 已知 + amount 已知
    ↓
自动触发 LLM 分类建议（不点按钮，静默）
    ↓
底部卡片展示 AI 建议：
┌──────────────────────────────┐
│ ✨ AI 推荐分类               │
│                              │
│  餐饮 ☕（置信度 92%）        │
│  商户：大家乐                │
│                              │
│  [确认] [修改分类]           │
└──────────────────────────────┘
    ↓
aiConfirmed = true（置信度 ≥ 0.9），自动入账
```

---

## 4. LLM Prompt（AI Pro）

### 4.1 分类建议

```
你是一个专业的记账分类助手。
请根据以下信息，推荐最合适的分类。

分类体系（只能选一个）：餐饮 / 交通 / 购物 / 居住 / 医疗 / 教育 / 娱乐 / 其他

金额：{amount} {currency}
商户名：{merchant}
备注：{note}
用户历史选择：{recent_categories}（如有）

请以 JSON 格式返回：
{
  "category": "分类名",
  "confidence": 0.0-1.0之间的置信度,
  "reasoning": "判断理由（1句话）"
}
```

### 4.2 AI Pro 计费

- **每次 OCR 成功 + 用户确认金额后**，扣 1 次 AI call
- `SubscriptionService.consumeAiCall()` 控制配额

---

## 5. 实现清单

| 优先级 | 任务 | 文件 |
|--------|------|------|
| P0 | 修改 `OcrResult` + 新增 `AmountCandidate` | `expense_ocr_data_source.dart` |
| P0 | 重写 Android `extractAmountCandidates` | `MainActivity.kt` |
| P0 | 重写 iOS `extractAmountCandidates` | `AppDelegate.swift` |
| P0 | 修改 Dart 层适配新返回结构 | `apple_vision_ocr_data_source.dart` |
| P0 | 底部弹窗 UI — 候选选择 | `add_expense_screen.dart` |
| P0 | 候选选择后金额回填 | `add_expense_screen.dart` |
| P1 | AI Pro：LLM 静默分类（金额确认后自动触发）| `expense_repository_impl.dart` / API |
| P1 | AI Pro：推荐结果确认卡片 | `add_expense_screen.dart` |
| P2 | 手动输入兜底（用户不选候选时）| `add_expense_screen.dart` |

---

## 6. 验收标准

- [ ] 同一张 HK$47.40 出租车票：候选列表包含 HK$47.40 和其他数字，不选错
- [ ] 大家乐 HK$44.00 收据：total 行置顶推荐
- [ ] 日期值 2024.00 出现在列表但标注"疑似日期"
- [ ] Free 用户：所有候选免费可见，用户选择后正常填入
- [ ] AI Pro 用户：金额确认后自动出现 AI 分类建议
- [ ] 手动输入始终可用（候选都不对时）
