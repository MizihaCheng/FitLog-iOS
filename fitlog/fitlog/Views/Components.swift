import SwiftUI

/// 带标签和单位后缀的输入框（对应 Android FitTextField / TodayTextField）
struct FitLabeledField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var suffix: String? = nil
    var decimal: Bool = true
    var multiline: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.fitSecondaryText)
            HStack {
                if multiline {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .lineLimit(2...4)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(decimal ? .decimalPad : .default)
                }
                if let suffix {
                    Text(suffix).foregroundStyle(Color.fitSecondaryText)
                }
            }
            .padding(12)
            .background(Color.fitCardSurface, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// 橙色（或指定色）的主操作按钮（对应 Android TodayPrimaryButton）
struct FitPrimaryButton: View {
    let title: String
    var color: Color = .fitAccent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(color, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
