import SwiftUI
import UIKit

/// 包一层 UIActivityViewController，弹出 iOS 系统分享面板
/// （对应 Android 的 Intent.ACTION_SEND 分享选择器）。
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// 用于 `.sheet(item:)` 触发分享的可识别载体。
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}
