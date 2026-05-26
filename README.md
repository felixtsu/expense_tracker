# Expense Tracker — Flutter 記帳 App

香港 AI 創業教育 workshop demo。同一份 Flutter codebase 跑 iOS + Android，示範一個 AI 記帳 App 如何把 rich client、SQLite、Supabase、Vercel API、LLM 和 Free / Pro 分層串起來。

## 项目状态

**Workshop demo ready ✅** — Tier A 可直接跑；Tier B Supabase + Vercel 可按文檔配置；Tier C IAP / restore / migration 是產品設計與後續開發方向。

| Tier | 狀態 | 說明 |
|------|------|------|
| Tier A | ✅ 可直接跑 | 本地記帳、OCR、AI 示範/降級、月報、CSV |
| Tier B | ✅ 代碼就緒，需配置 | Supabase anonymous auth、cloud sync、Vercel JWT + Pro |
| Tier C | 📋 設計中 | 真 IAP、restore purchase、換機資料遷移 |

## 快速開始：只跑 Tier A

```bash
git clone -b feature/supabase-sync https://github.com/felixtsu/expense_tracker.git
cd expense_tracker
flutter pub get
flutter test
./scripts/run-ios.sh
```

Tier A 不需要：

- Supabase
- Vercel
- DeepSeek / OpenRouter API key
- Apple Developer / Google Play Console

## 進階：啟用 Supabase + Vercel

1. 建 Supabase project，開 Anonymous sign-ins。
2. 在 Supabase SQL Editor 執行 [`supabase/migrations/001_sync_schema.sql`](supabase/migrations/001_sync_schema.sql)。
3. 複製 env 模板：

   ```bash
   cp .env.example .env.local
   ```

4. 填入：

   ```text
   DEEPSEEK_API_KEY=...
   SUPABASE_URL=...
   SUPABASE_SERVICE_ROLE_KEY=...   # Vercel only
   DEV_PRO_SECRET=...
   API_BASE_URL=https://your-vercel-app.vercel.app
   SUPABASE_ANON_KEY=...
   ```

5. 部署 Vercel：

   ```bash
   npm install
   vercel
   vercel --prod
   ```

6. 用配置後的 `.env.local` 跑 app：

   ```bash
   ./scripts/run-ios.sh
   ```

詳細流程：

- [docs/SUPABASE-SETUP.md](docs/SUPABASE-SETUP.md)
- [docs/API-DEPLOY.md](docs/API-DEPLOY.md)
- [docs/API-AUTH.md](docs/API-AUTH.md)

## OCR 功能（Phase 2）

详见 [docs/OCR-DEVELOPMENT.md](docs/OCR-DEVELOPMENT.md)

## 云同步与 IAP

**方案：** 無用戶註冊 UI；Supabase 匿名登入；Pro 解鎖雲同步 + AI；換機遷移見設計文檔階段 2。

- 设计：[docs/SYNC-AND-IAP-DESIGN.md](docs/SYNC-AND-IAP-DESIGN.md)
- Supabase 配置：[docs/SUPABASE-SETUP.md](docs/SUPABASE-SETUP.md)
- 待办：[TODO.md](TODO.md)

構建示例：

```bash
SUPABASE_URL=https://xxx.supabase.co \
SUPABASE_ANON_KEY=eyJ... \
./scripts/run-ios.sh
```

## 技術棧

- **框架**：Flutter
- **架构**：Clean Architecture（presentation / domain / data 三层）
- **依賴**：sqflite、fl_chart、provider、intl、supabase_flutter

## Build 產物

| 平台 | 路径 | 状态 |
|------|------|------|
| Android | `build/app/outputs/flutter-apk/app-debug.apk` | ✅ |
| iOS | `build/ios/iphonesimulator/Runner.app` | ✅ |

## 功能清單

| 功能 | 状态 | 说明 |
|------|------|------|
| 支出列表 | ✅ | 首页展示所有支出记录 |
| 添加支出 | ✅ | 金额/类别/备注/日期 |
| OCR 拍照识别 | ✅ | iOS Vision / Android ML Kit |
| AI 分类 | ✅ | Vercel API，失败时本地 mock fallback |
| 月度报表 | ✅ | 饼图 + 分类占比 |
| AI 月报洞察 | ✅ | Vercel API |
| 数据持久化 | ✅ | SQLite 本地存储 |
| 导出 CSV | ✅ | 导出按钮 |
| Supabase 云同步 | ✅ | 需配置 Supabase + Pro/demo |
| 真 IAP / restore | 📋 | 后续开发 |

## iOS / Android 双平台构建

```bash
cd expense_tracker

# Android
flutter build apk --debug

# iOS（需 Mac + Xcode）
flutter build ios --simulator --no-codesign
```

## 模拟器测试

### Android

```bash
# 启动模拟器
~/Library/Android/sdk/emulator/emulator -avd <avd_name>

# 查看已连接设备
~/Library/Android/sdk/platform-tools/adb devices

# 截图
~/Library/Android/sdk/platform-tools/adb -s emulator-5554 shell screencap /sdcard/screen.png
~/Library/Android/sdk/platform-tools/adb pull /sdcard/screen.png
```

### iOS

使用 **idb**（iOS Development Bridge，Facebook 开源）：

```bash
# 安装 idb
brew install --cask companion
brew tap facebook/fb
brew install idb-companion

# Python 环境（推荐 venv）
python3.11 -m venv /tmp/idb-venv
/tmp/idb-venv/bin/pip install fb-idb

# 列出模拟器
/tmp/idb-venv/bin/idb list-targets

# 常用命令
/tmp/idb-venv/bin/idb screenshot --udid <uuid> <path>     # 截图
/tmp/idb-venv/bin/idb ui tap --udid <uuid> <x> <y>       # 点击
/tmp/idb-venv/bin/idb ui text --udid <uuid> <text>        # 文本输入
/tmp/idb-venv/bin/idb ui describe-all --udid <uuid>       # UI 层级
/tmp/idb-venv/bin/idb ui key-sequence --udid <uuid> <k>   # 按键序列
/tmp/idb-venv/bin/idb launch --udid <uuid> <bundle_id>    # 启动 APP
/tmp/idb-venv/bin/idb install --udid <uuid> <app_path>   # 安装 APP
/tmp/idb-venv/bin/idb terminate --udid <uuid> <bundle_id>  # 关闭 APP
```

#### iOS 测试坐标参考

| 元素 | 坐标（iPhone 17 Pro, 402×874） |
|------|------|
| 浮动"记一笔"按钮 | (330, 716) |
| 金额字段 | (201, 162) |
| 类别下拉 | (201, 234) |
| 备注字段 | (201, 330) |
| 保存按钮 | (201, 608) |
| 底部导航-报表 | (335, 800) |

#### idb ui text ⚠️ Flutter iOS Bug

**问题**：`idb ui text` 对 Flutter iOS TextField 有关键盘状态残留，导致字符追加 + 产生额外 "g" 字符。

**规律**：
- 第一次输入（字段干净）→ ✅ 正常
- 关键盘后再次输入 → ❌ 追加内容 + 产生 "g"

**解决**：**一次输入原则** — 金额只输入一次，不反复切换键盘。

## Git Tag 结构（教学用）

```
v1.0-base          # 基础项目框架
v2.0-ui            # Module B 完成（记账 UI）
v3.0-native        # Module C 完成（Siri/Vision/Widget）
v4.0-ai            # Module D 完成（AI 分类）
v5.0-insights      # Module E 完成（月报图表）
v6.0-persistence   # Module F 完成（SQLite + 云同步）
v7.0-iap           # Module G 完成（StoreKit / Play Billing）
```

## 课程 Module 结构

| Module | 内容 | 引入概念 |
|--------|------|----------|
| A | 产品与工作流设计 | 记账心理 / 行为改变 |
| B | UI/交互设计 | 快速记账入口 + 月报图表 |
| C | Native/设备能力 | Siri Shortcuts / Vision OCR / Widget |
| D | AI 结构化分类 | LLM 分类 + 置信度 |
| E | 洞察与行为改变 | 月报摘要 + 预算预警 |
| F | 后端与持久化 | SQLite + Supabase |
| G | 变现与 IAP | Free/Pro 分层 + StoreKit 2 |

## 相关文档

- [docs/SYNC-AND-IAP-DESIGN.md](docs/SYNC-AND-IAP-DESIGN.md) — 云同步、匿名 Auth、IAP、迁移、Workshop 分层
- [docs/OCR-DEVELOPMENT.md](docs/OCR-DEVELOPMENT.md) — OCR 开发与测试
- [docs/OCR-V2-DESIGN.md](docs/OCR-V2-DESIGN.md) — OCR 候选与 AI Pro 交互
- [TODO.md](TODO.md) — 项目待办
- [TESTING.md](TESTING.md) — 测试与 AI 演示模式
- `../SPEC.md` — 项目完整规格说明书（若存在）
- `../app-dev-course-decomposition.md` — 课程分解（若存在）

## 项目路径

```
tenth_project_hk/app-dev-sharing-0530/expense_tracker_app/
```
