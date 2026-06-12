import SwiftUI

/// 今日 AI 总结页（今日页点「今日 AI 总结」弹出，被动式按需生成）。
struct TodaySummaryView: View {
    @EnvironmentObject var store: FitStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("deepseek_api_key") private var apiKey = ""

    let date: String

    enum Phase {
        case loading
        case done(String)
        case failed(String)
    }

    @State private var phase: Phase = .loading

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch phase {
                    case .loading:
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("正在让 DeepSeek 总结今天的训练…")
                                .font(.subheadline).foregroundStyle(Color.fitSecondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)

                    case .done(let text):
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles").foregroundStyle(Color.fitAccent)
                            Text("今日小结").font(.headline).foregroundStyle(Color.fitPrimaryText)
                        }
                        Text(text)
                            .font(.body)
                            .foregroundStyle(Color.fitPrimaryText)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("由 DeepSeek 生成，仅供参考")
                            .font(.caption2).foregroundStyle(Color.fitTertiaryText)

                    case .failed(let message):
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 36)).foregroundStyle(Color.fitSecondaryText)
                            Text(message)
                                .font(.subheadline).foregroundStyle(Color.fitSecondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                }
                .padding(20)
            }
            .background(Color.fitBackground.ignoresSafeArea())
            .navigationTitle("今日 AI 总结")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { Task { await load() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
        }
        .task { await load() }
    }

    private var isLoading: Bool {
        if case .loading = phase { return true }
        return false
    }

    private func load() async {
        let hasTrainingToday = store.trainingRecords.contains { $0.date == date }
        guard hasTrainingToday else {
            phase = .failed("今天还没有训练记录，先记一条再来总结吧。")
            return
        }
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            phase = .failed("还没填 DeepSeek API Key。请到「我的」页填入后再来。")
            return
        }
        phase = .loading
        do {
            let summary = try await TodaySummary.generate(store: store, apiKey: apiKey, date: date)
            phase = .done(summary)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
