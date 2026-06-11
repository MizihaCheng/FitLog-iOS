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
- [x] **第 5 步** 数据备份：ProfileView 导出/导入 JSON（fileExporter/fileImporter + JSONDocument）
- [x] **第 6 步** 趋势页：Swift Charts 体重折线 + 目标虚线 + 统计（最新/变化/训练次数）。可后续加训练量图
- [x] **第 7 步** 日历页：自定义月历（周一起始、翻月），训练日标圆点，点日期看当天训练
- [ ] **第 8 步** 肌肉激活图（MuscleMap）—— 移植难点。**前置**：训练表单需先采集 bodyParts（部位），当前只采集类型/时长/备注，否则肌肉图无数据
- [x] **第 9 步** PDF 导出：PDFReport 生成训练报告（按日期分组+组+分页），ProfileView「导出 PDF 报告」
- [x] **第 10 步** UI 还原：
  - [x] (一) 暖色主题 —— FitColors.swift 动态色、橙色 AccentColor、各页米色背景+白卡片
  - [x] (二) 弹窗表单（AddXxx/EditGoal）统一暖色背景+白卡片
  - 后续可选：字体层级、卡片圆角/间距更精细对齐 Android

> 顺序可调。原则是先把高频核心（记训练、看记录、记体重）做扎实，再做趋势/日历/肌肉图等增强，最后统一美化。

---

## 进度备注（第一轮搭建）

- 第一轮（功能优先版）第 0–10 步均完成。但用户指出与 Android 版"只是神似"，故启动第二轮逐屏 1:1 还原（见下）。
- 同一份计划也记在 Claude 长期记忆 `fitlog-ios-port.md`，两边保持同步。

---

## 第二轮：逐屏严格 1:1 还原（进行中）

用户要求对照 Android 各屏源码逐屏精读后重写，尽量 1:1。定序：今日 → 日历+当日详情 → 记录 → 趋势 → 我的 → 肌肉图。

**关键架构修正**（第一轮放错的）：日历是核心枢纽，点某天弹「当日详情」录入体重/围度并导出当日 PDF；体重/围度录入**不在**「我的」页；PDF 是**按单日**导出。

- [x] **今日页**（commit 2264e20 / dc865ad / ccdce56 / 66e7e98）：自定义头部 + 目标进度环 + 打卡行 + 快速记录 + 今日训练列表；结构化训练录入（力量/有氧/拉伸、部位多选、动作明细多组、历史动作自动补全）；体重/围度录入弹窗对齐原版
- [x] **日历 + 当日详情**（commit 3c5e70f）：圆角方块 + 三色圆点(橙体重/蓝训练/绿围度) + 图例；点某天弹 DayDetailView（导出本日 PDF / 体重 / 围度 / 肌肉激活占位 / 当天训练）；PDFReport.dayReport 单日 PDF
- [x] **记录页**（commit 72d33d3）：搜索 + 可展开筛选（时间范围/训练类型/数据类型/清除）+ 按天分组卡片，点卡片弹当日详情
- [x] **趋势页**（commit dd1166f）：体重趋势折线 / 统计复盘（本周本月 + 6 项统计 + 训练类型分布）/ 围度趋势（指标选择 + 折线）
- [x] **我的页**（commit 8dfb964）：体重概览 / 目标体重（设目标）/ 数据管理（导出 JSON·**导出明细 CSV**·导入 JSON·清除训练/体重/围度·重置目标·清空全部，均带确认）
- [ ] **肌肉激活图**（← 明天从这里开始）：移植 Android `muscle/MuscleMap.kt` 的正反面人体 SVG 路径，按训练部位高亮（主练/辅练），用于 DayDetailView（当前占位）和 PDF。需要 `muscle/MuscleMap.kt` + `MuscleMapper.kt`（部位→肌群映射）+ `MuscleActivation.kt`

**已弃用未删**（无人引用，清理可选）：AddWeightView / AddMeasurementView / AddTrainingView / EditGoalView / AddSetView / WorkoutDetailView / PDFReport.trainingReport

**停止点**：2026-06-11，五屏还原完成并 push（最新 commit `8dfb964`）。明天继续第 6 步肌肉图。
