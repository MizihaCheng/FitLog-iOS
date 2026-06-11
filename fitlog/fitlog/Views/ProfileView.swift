import SwiftUI
import UniformTypeIdentifiers

struct ProfileView: View {
    @EnvironmentObject var store: FitStore

    @State private var targetInput = ""
    @State private var loadedTarget = false

    @State private var showingJSONExporter = false
    @State private var showingCSVExporter = false
    @State private var showingImporter = false
    @State private var showingImportAlert = false
    @State private var importMessage = ""
    @State private var pendingClear: ClearAction?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                weightOverviewCard
                targetCard
                dataManagementCard
            }
            .padding(.horizontal, 20).padding(.vertical, 18)
        }
        .background(Color.fitBackground.ignoresSafeArea())
        .onAppear {
            guard !loadedTarget else { return }
            loadedTarget = true
            targetInput = store.goal.targetWeightKg
        }
        .fileExporter(
            isPresented: $showingJSONExporter,
            document: JSONDocument(data: store.exportData() ?? Data()),
            contentType: .json,
            defaultFilename: "FitLog_backup_\(fitTodayString())"
        ) { _ in }
        .fileExporter(
            isPresented: $showingCSVExporter,
            document: CSVDocument(text: fitDetailedCSV(store: store)),
            contentType: .commaSeparatedText,
            defaultFilename: "FitLog_records_\(fitTodayString())"
        ) { _ in }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
        .alert("导入", isPresented: $showingImportAlert) {
            Button("好", role: .cancel) {}
        } message: { Text(importMessage) }
        .alert(item: $pendingClear) { action in
            Alert(
                title: Text(action.title),
                message: Text(action.message),
                primaryButton: .destructive(Text("确定")) { action.perform(store) },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    // MARK: - 体重概览

    private var latest: DailyWeightRecord? { store.weightRecords.max { $0.date < $1.date } }
    private var earliest: DailyWeightRecord? { store.weightRecords.min { $0.date < $1.date } }
    private var weightDays: Int {
        Set(store.weightRecords.filter { !$0.weightKg.isEmpty }.map { $0.date }).count
    }

    private var weightOverviewCard: some View {
        let change: (text: String, color: Color)? = {
            guard let s = earliest.flatMap({ Double($0.weightKg) }),
                  let c = latest.flatMap({ Double($0.weightKg) }) else { return nil }
            let d = c - s
            if d < 0 { return ("-\(fitFormatWeight(abs(d))) kg", .fitPositiveGreen) }
            if d > 0 { return ("+\(fitFormatWeight(d)) kg", .fitWarningRed) }
            return ("0 kg", .fitPrimaryText)
        }()

        return VStack(alignment: .leading, spacing: 14) {
            Text("体重概览").font(.headline).foregroundStyle(Color.fitPrimaryText)
            HStack(spacing: 10) {
                statCell(latest.flatMap { $0.weightKg.isEmpty ? nil : "\($0.weightKg) kg" } ?? "--", "当前体重")
                statCell(earliest.flatMap { $0.weightKg.isEmpty ? nil : "\($0.weightKg) kg" } ?? "--", "起始体重")
            }
            HStack(spacing: 10) {
                statCell(change?.text ?? "--", "累计变化", valueColor: change?.color ?? .fitPrimaryText)
                statCell(weightDays > 0 ? "\(weightDays) 天" : "--", "记录天数")
            }
        }
        .fitCard()
    }

    // MARK: - 目标体重

    private var targetCard: some View {
        let currentVal = latest.flatMap { Double($0.weightKg) }
        let targetVal = Double(store.goal.targetWeightKg)
        let distance: (text: String, color: Color) = {
            guard let cur = currentVal, let tgt = targetVal else { return ("--", .fitPrimaryText) }
            let diff = cur - tgt
            if abs(diff) < 0.05 { return ("已达到", .fitPositiveGreen) }
            return ("还差 \(fitFormatWeight(abs(diff))) kg", .fitPrimaryText)
        }()

        return VStack(alignment: .leading, spacing: 14) {
            Text("目标体重").font(.headline).foregroundStyle(Color.fitPrimaryText)
            HStack(spacing: 10) {
                statCell(currentVal.map { "\(fitFormatWeight($0)) kg" } ?? "暂无", "当前体重")
                statCell(store.goal.targetWeightKg.isEmpty ? "未设置" : "\(store.goal.targetWeightKg) kg", "目标体重")
                statCell(distance.text, "距离目标", valueColor: distance.color)
            }
            FitLabeledField(label: "设置目标体重", text: $targetInput, placeholder: "目标体重", suffix: "kg")
            FitPrimaryButton(title: "保存目标") { store.setTargetWeight(targetInput) }
        }
        .fitCard()
    }

    // MARK: - 数据管理

    private var dataManagementCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("数据管理").font(.headline).foregroundStyle(Color.fitPrimaryText)

            actionRow("导出备份（JSON）", icon: "square.and.arrow.up") { showingJSONExporter = true }
            actionRow("导出明细（CSV）", icon: "tablecells") { showingCSVExporter = true }
            actionRow("导入备份（JSON）", icon: "square.and.arrow.down") { showingImporter = true }

            Divider().background(Color.fitDivider).padding(.vertical, 4)

            actionRow("清除训练记录", icon: "trash", danger: true) { pendingClear = .training }
            actionRow("清除体重记录", icon: "trash", danger: true) { pendingClear = .weight }
            actionRow("清除围度记录", icon: "trash", danger: true) { pendingClear = .measurement }
            actionRow("重置目标", icon: "arrow.counterclockwise", danger: true) { pendingClear = .goal }
            actionRow("清空全部数据", icon: "exclamationmark.triangle", danger: true) { pendingClear = .all }
        }
        .fitCard()
    }

    private func actionRow(_ title: String, icon: String, danger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 22)
                    .foregroundStyle(danger ? Color.fitWarningRed : Color.fitAccent)
                Text(title)
                    .foregroundStyle(danger ? Color.fitWarningRed : Color.fitPrimaryText)
                Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 通用

    private func statCell(_ value: String, _ label: String, valueColor: Color = .fitPrimaryText) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline).foregroundStyle(valueColor).multilineTextAlignment(.center)
            Text(label).font(.caption2).foregroundStyle(Color.fitSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Color.fitBackground, in: RoundedRectangle(cornerRadius: 14))
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                importMessage = store.importData(data) ? "导入成功" : "文件格式不正确，导入失败"
            } catch {
                importMessage = "读取文件失败：\(error.localizedDescription)"
            }
        case .failure(let error):
            importMessage = "选择文件失败：\(error.localizedDescription)"
        }
        showingImportAlert = true
    }
}

/// 清除类操作（带确认）
enum ClearAction: Identifiable {
    case training, weight, measurement, goal, all
    var id: String { String(describing: self) }

    var title: String {
        switch self {
        case .training: return "清除训练记录"
        case .weight: return "清除体重记录"
        case .measurement: return "清除围度记录"
        case .goal: return "重置目标"
        case .all: return "清空全部数据"
        }
    }
    var message: String {
        switch self {
        case .all: return "将删除全部训练、体重、围度和目标，且无法撤销。建议先导出备份。"
        default: return "此操作无法撤销，确定继续？"
        }
    }
    @MainActor
    func perform(_ store: FitStore) {
        switch self {
        case .training: store.clearTrainingRecords()
        case .weight: store.clearWeightRecords()
        case .measurement: store.clearMeasurements()
        case .goal: store.resetGoal()
        case .all: store.clearAll()
        }
    }
}
