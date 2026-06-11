# FitLog iOS 移植计划

把 Android 版 FitLog（`D:\MyAIProject\FitLog`，Kotlin + Jetpack Compose）移植成 iOS 原生 app（SwiftUI）。

---

## 工作流（重要）

- **改代码**：在 Windows 上由 Claude 改 + commit + push 到 GitHub（`github.com/MizihaCheng/FitLog-iOS`）。
- **验证**：用户在 Mac 上 `git pull` + Xcode `⌘R` 跑模拟器验证。
- iOS 代码**无法在 Windows 编译**，对错只能靠 Mac 验证。所以每步要小、可独立验证。
- 节奏：**一步一步做**，每步做完用户测一眼再继续（省 token）。

### 用户在 Mac 上拉取更新
```bash
cd ~/Developer/FitLog-iOS        # 换成实际 clone 路径
git pull
# 然后回 Xcode 按 ⌘R
```
打开工程用 `open fitlog/fitlog.xcodeproj`（不是 Package.swift，已删）。

---

## 工程结构

- Xcode 26 工程，`objectVersion 77`，用 `PBXFileSystemSynchronizedRootGroup`：
  **源码放进 `fitlog/fitlog/` 文件夹即自动加入编译 target，不用手动改 `project.pbxproj`。**
- 入口：`fitlog/fitlog/App/FitLogApp.swift`（`@main`，TabView）。
- Bundle id `donson.fitlog`，部署目标 iOS 26.4。
- 目录：`App/`（入口+ContentView）、`Models/`、`Storage/`、`Views/`。

---

## 总原则

1. **先功能，后 UI 还原**：先把每个页面的功能跑通（哪怕样式朴素），全部功能就绪后再对照 Android 版统一还原外观。
2. **UI 还原参照**：Android 的 `ui/theme/Color.kt`、`Theme.kt`、`Type.kt`、`UiTokens.kt`、`components/CommonComponents.kt` —— 颜色、字体、圆角、间距都从这些里抠。
3. **数据模型**已在 `Models/` 定义：`TrainingRecord`、`ExerciseSet`、`DailyWeightRecord`、`BodyMeasurementRecord`、`GoalRecord`。

---

## Android 版参照（各屏幕源码，行数=复杂度）

| iOS Tab | Android 文件 | 行数 | 说明 |
|---|---|---|---|
| 今日 | `screens/TodayScreen.kt` | 1784 | 最核心：记训练、记每组(组数/重量/次数)、肌肉图 |
| 记录 | `screens/RecordsScreen.kt` | 523 | 历史记录列表/筛选/编辑 |
| 趋势 | `screens/TrendsScreen.kt` | 506 | 图表（体重/训练量趋势）—— 用 Swift Charts |
| 日历 | `screens/CalendarScreen.kt` | 276 | 按日历看训练分布 |
| 我的 | `screens/ProfileScreen.kt` | 435 | 目标设置、备份、导出（Android 多一个 Tab） |

其他模块：`muscle/`（肌肉激活图 MuscleMap，~550 行）、`PdfExporter.kt`（导出 PDF）、`FitBackup.kt`（备份导入导出）、`StatsUtils.kt`（统计计算）。

**存储格式**：Android 用 SharedPreferences 存多个 JSON 字符串（`org.json`）。iOS 目前用原生 Codable 存单个 `Documents/fitlog_data.json`。两者**字节级不兼容**；只有要把老 Android 手机的数据搬到 iOS 时才需要做格式转换 —— 列为可选后期任务。

---

## 分步路线图

- [x] **第 0 步** 工程骨架跑通，4 个 Tab 显示
- [x] **第 1 步** FitStore JSON 持久化 + 今日页训练记录（增 / 列表 / 滑动删除 / 空态）
- [x] **第 2 步** 记录页：全部历史训练列表，按日期分组（倒序）、滑动删除、空态（编辑待后续）
- [x] **第 3 步** 训练组（ExerciseSet）：训练详情页 WorkoutDetailView + 加组表单 AddSetView，今日/记录行可点进详情
- [x] **第 4 步** 「我的」Tab（ProfileView）：目标 + 体重记录 + 围度记录，含 EditGoalView / AddWeightView / AddMeasurementView
- [ ] **第 5 步** 「我的」页增强：数据备份/导入、导出（在 ProfileView 上加）
- [x] **第 6 步** 趋势页：Swift Charts 体重折线 + 目标虚线 + 统计（最新/变化/训练次数）。可后续加训练量图
- [x] **第 7 步** 日历页：自定义月历（周一起始、翻月），训练日标圆点，点日期看当天训练
- [ ] **第 8 步** 肌肉激活图（MuscleMap）—— 移植难点，独立排期
- [ ] **第 9 步** PDF 导出 / 备份文件分享
- [ ] **第 10 步** UI 还原大阶段：对照 Android theme/UiTokens 统一配色、字体、圆角、间距，做到外观接近原版

> 顺序可调。原则是先把高频核心（记训练、看记录、记体重）做扎实，再做趋势/日历/肌肉图等增强，最后统一美化。

---

## 进度备注

- 最近完成：第 7 步 日历页（commit `9b53089`）。5 个 Tab 功能均已可用。
- 下一步：剩 第 5 步备份/导出、第 8 步肌肉图、第 9 步 PDF、第 10 步 UI 还原。建议接下来做 UI 还原或备份。
- 同一份计划也记在 Claude 长期记忆 `fitlog-ios-port.md`，两边保持同步。
