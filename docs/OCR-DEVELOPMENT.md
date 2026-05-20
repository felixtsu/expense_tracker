# OCR 功能开发进度

_最后更新：2026-05-19_

## 目标
拍照识别收据，自动提取金额和商户名，完全离线，无需网络。

---

## 架构概览

```
Flutter (Dart)
├── Android → MethodChannel → MainActivity.kt (Kotlin + Google ML Kit)
└── iOS     → MethodChannel → AppDelegate.swift   (Swift  + Apple Vision)
```

**通道名：**
- Android：`expense_tracker/ocr_android`
- iOS：`expense_tracker/ocr`

**测试图片（Henry 提供，5/16 HK）：**
- 出租车：`/Users/clawcubic/.openclaw/media/inbound/2026-05-16_香港的士_西九龙-理工大_DK5571_HK47.40---151b84f3-0588-4140-8010-175095982bf5.jpg`
- 大家乐：`/Users/clawcubic/.openclaw/media/inbound/2026-05-16_大家乐午饭_香港理工大_HK44.00---c715fd70-1b02-40af-82f8-f596f3c256bb.jpg`

---

## 平台实现

### Android（Google ML Kit）

**依赖：** `com.google.mlkit:text-recognition:16.0.1`
**import:** `com.google.mlkit.vision.text.latin.TextRecognizerOptions`
**NDK:** `25.1.8937393`（`26.1.10909125` 未安装，用 `--android-skip-build-dependency-validation` 绕过）

**文件：** `android/app/src/main/kotlin/com/cubicbird/expense_tracker/MainActivity.kt`

**amount 提取逻辑（Kotlin）：**
```kotlin
// 1. 优先匹配 explicit total 行（total/总计/合计/金额/总额/实付/应付）
// 2. 然后找所有 ¥ 金额，跳过 1900~2100 的值（疑似年份）
// 3. 返回最大值
```

---

### iOS（Apple Vision Framework）

**依赖：** Native Vision framework（无需额外依赖）
**文件：** `ios/Runner/AppDelegate.swift`

**amount 提取逻辑（Dart 层）：**
```dart
// lib/data/datasources/apple_vision_ocr_data_source.dart
// 1. 优先匹配 explicit total（total/总计/合计/金额/总额/实付/应付/小计）
// 2. HK$ / HKD / 港幣专用正则
// 3. 跳过 1900~2100 无小数位的值（疑似年份）
// 4. 返回最大值
```

**iOS 特有配置：**
- `request.recognitionLevel = .accurate`
- `request.usesLanguageCorrection = false`（避免数字被误修正）

---

## 已知问题 & 修复历史

### 2026-05-19

| 问题 | 原因 | 修复 |
|------|------|------|
| Android OCR 识别出 2024 | 正则把日期当金额 | 跳过 1900~2100 的值 |
| iOS 相机报错后无法选相册 | image_picker 抛异常未捕获 | catch `PlatformException`，fallback 到 gallery |
| iOS 金额识别错误（离谱） | `_extractAmount` 无日期过滤 | Cursor 重写正则，加 HK$ 模式 + 日期过滤 |
| iOS 相机图标点不了（模拟器）| 相机不可用时应走相册 | bottom sheet 保持，但 catch 异常后自动切相册 |

---

## 待解决

- [ ] **iOS OCR 准确性** — 需要真机测试确认 Vision 识别 HK 收据效果
- [ ] **iOS 相机 fallback 流程** — 需用户确认是否正常触发
- [ ] **金额精度** — Android 打车识别出 37.48（正确 37.40），差 0.08

---

## 快速测试指南

### 模拟器准备

**Android：**
```bash
# 推送测试图片到相册
adb push taxi.jpg /sdcard/Pictures/
adb push restaurant.jpg /sdcard/Pictures/
adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE \
  -d file:///sdcard/Pictures/taxi.jpg
```

**iOS：**
```bash
# 添加到模拟器相册
xcrun simctl addmedia booted <image_path>
```

### 测试步骤
1. 打开 Expense Tracker → 点「十」→ 点相机按钮
2. Android：选"拍照"或"从相册选"；iOS：点"拍照"后应自动 fallback 到相册
3. 选择测试图片
4. 查看识别结果

### 抓 Log

**Android：**
```bash
adb logcat -s MainActivity:D | grep OCR
```

**iOS（Xcode）：**
```
Product → Open Recent Logs → Simulator → system.log
# 搜索 "[AppleVision OCR]"
```
