# 测试指南

环境已由脚本预配置；你只需完成 **需要你本人操作** 的步骤。

## 已自动完成

- Flutter SDK：Homebrew `brew install --cask flutter`（`/opt/homebrew/bin/flutter`）
- `flutter pub get`
- 单元/Widget 测试修复（OCR 在测试环境使用 stub，不崩溃）
- **设置 → AI 演示模式**：可测 AI 分类与月报洞察，无需真实 IAP

## 一键启动（iOS 模拟器）

```bash
cd /Users/felix/Work/10thprj/expense_tracker
chmod +x scripts/run-ios.sh
./scripts/run-ios.sh
```

或：

```bash
cd /Users/felix/Work/10thprj/expense_tracker
open -a Simulator
flutter run -d ios
```

## 跑自动化测试

```bash
cd /Users/felix/Work/10thprj/expense_tracker
flutter test
```

## Workshop 与账号要求

实操分层（无邮箱注册、Supabase 匿名登录、IAP 迁移等）见 **[docs/SYNC-AND-IAP-DESIGN.md](docs/SYNC-AND-IAP-DESIGN.md)**。

- **Tier A（全班）：** 本地记账、OCR、AI 演示模式、CSV — 无需付费 Apple/Google 开发者账号  
- **Tier B（可选）：** Supabase 匿名登录演示 — 免费注册 Supabase 即可  
- **Tier C（讲师）：** 真 IAP、恢复购买、数据迁移 — 见文档 Cheatsheet

## 需要你手动完成

### 1. OCR（Phase 2 重点）

1. 准备 1–2 张香港收据照片（的士、大家乐等）
2. 导入模拟器相册：
   ```bash
   xcrun simctl addmedia booted /path/to/receipt.jpg
   ```
3. App → **记一笔** → 相机图标 → **从相册选择**（模拟器无真机相机）
4. 确认识别金额与商户，保存一笔

**真机**：相机可用，建议在真机上再验一遍 Vision/ML Kit 准确度。

### 2. AI 功能

1. 首页 **支出** → 右上角 **设置** → 打开 **AI 演示模式**
2. **记一笔** → **AI 自动分类**（需网络，走 Vercel API；服务端需配置 `DEEPSEEK_API_KEY`，见 [docs/API-DEPLOY.md](docs/API-DEPLOY.md)）
3. **报表** → **AI 月报洞察**

### 3. Android（可选）

本机未安装 Android SDK。若要测 Android：

1. 安装 [Android Studio](https://developer.android.com/studio)
2. 完成 SDK 与模拟器创建
3. `flutter doctor --android-licenses`
4. `flutter run -d android`

### 4. 真机 / 无线调试

- 真机需信任开发者、开启 Developer Mode
- 当前 `flutter doctor` 可能对局域网设备有提示，用 USB 连接更稳

## 环境检查

```bash
flutter doctor -v
```

| 项 | 状态 |
|----|------|
| Flutter | ✅ Homebrew cask |
| Xcode / iOS | ✅ |
| Android SDK | ❌ 需自行安装 |
