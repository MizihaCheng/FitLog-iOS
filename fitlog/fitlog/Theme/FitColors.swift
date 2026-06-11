import SwiftUI

extension Color {
    /// 按浅色 / 深色十六进制生成动态颜色
    private static func fitDynamic(light: UInt, dark: UInt) -> Color {
        Color(uiColor: UIColor { trait in
            let hex = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xff) / 255,
                green: CGFloat((hex >> 8) & 0xff) / 255,
                blue: CGFloat(hex & 0xff) / 255,
                alpha: 1
            )
        })
    }

    // 对应 Android UiTokens / Color.kt
    static let fitBackground    = fitDynamic(light: 0xF6F2EB, dark: 0x1A1714)
    static let fitCardSurface   = fitDynamic(light: 0xFFFFFF, dark: 0x262220)
    static let fitPrimaryText   = fitDynamic(light: 0x272219, dark: 0xF2ECE2)
    static let fitSecondaryText = fitDynamic(light: 0x6E6557, dark: 0xA89E8E)
    static let fitTertiaryText  = fitDynamic(light: 0xA89E8E, dark: 0x7E756A)
    static let fitDivider       = fitDynamic(light: 0xEDE7DB, dark: 0x38332E)
    static let fitAccent        = fitDynamic(light: 0xE2703A, dark: 0xEC8049)
    static let fitDeepOrange    = fitDynamic(light: 0xC2531F, dark: 0xD8632E)
    static let fitPositiveGreen = fitDynamic(light: 0x5E9E6E, dark: 0x6FB87E)
    static let fitWarningRed    = fitDynamic(light: 0xD9534F, dark: 0xE8716D)
    static let fitTrainingBlue  = fitDynamic(light: 0x5B8FB0, dark: 0x6FA5C6)
}

extension View {
    /// 统一的页面外观：隐藏 List 默认底色，铺暖米色背景
    func fitListChrome() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.fitBackground.ignoresSafeArea())
    }

    /// 把列表行底色设为白色卡片
    func fitCardRow() -> some View {
        self.listRowBackground(Color.fitCardSurface)
    }
}
