import SwiftUI

/// 肌肉激活图（正面 + 背面），数据来自 [MuscleMap]，强度来自 [MuscleMapper]。
/// 对应 Android muscle/MuscleMapView.kt。
///
/// 用法：MuscleMapView(highlights: dayMuscleHighlights(records:sets:))

// MARK: - 配色（与 app 橙色主题一致，对照 Android MuscleMapView 的常量）

private enum MuscleColors {
    static let primaryFill = Color(red: 0.949, green: 0.420, blue: 0.114)   // F26B1D
    static let primaryStroke = Color(red: 0.761, green: 0.267, blue: 0.020) // C24405
    static let secondaryFill = Color(red: 0.984, green: 0.780, blue: 0.612) // FBC79C
    static let secondaryStroke = Color(red: 0.933, green: 0.624, blue: 0.369) // EE9F5E
    static let baseFill = Color(red: 0.894, green: 0.855, blue: 0.796)      // E4DACB
    static let baseStroke = Color(red: 0.827, green: 0.780, blue: 0.706)    // D3C7B4
    static let chipSecondaryText = Color(red: 0.478, green: 0.231, blue: 0.071) // 7A3B12
}

private let figureGap: CGFloat = 36     // 两人像间距（viewBox 单位）
private let strokeViewbox: CGFloat = 1.4 // 描边宽度（viewBox 单位，随缩放折算）

// MARK: - 预解析路径（viewBox 坐标，背面已平移到 0..724）

enum MuscleGeometry {
    static let frontPaths: [String: Path] = build(MuscleMap.front, offsetX: 0)
    static let backPaths: [String: Path] = build(MuscleMap.back, offsetX: MuscleMap.backOffsetX)

    private static func build(_ map: [String: [String]], offsetX: CGFloat) -> [String: Path] {
        var result: [String: Path] = [:]
        for (slug, ds) in map {
            var path = Path()
            for d in ds { path.addPath(SVGPath.parse(d)) }
            if offsetX != 0 {
                path = path.applying(CGAffineTransform(translationX: -offsetX, y: 0))
            }
            result[slug] = path
        }
        return result
    }
}

private struct FigurePlacement {
    let scale: CGFloat
    let dx: CGFloat
    let dy: CGFloat
    /// viewBox 点 -> 屏幕点：screen = scale * p + (dx, dy)
    var transform: CGAffineTransform {
        CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: dx, ty: dy)
    }
}

/// 计算正面 / 背面两个人像的摆放：宽屏并排，窄屏上下。
private func placements(_ w: CGFloat, _ h: CGFloat, sideBySide: Bool) -> (front: FigurePlacement, back: FigurePlacement) {
    let vw = MuscleMap.viewW, vh = MuscleMap.viewH
    if sideBySide {
        let halfW = (w - figureGap) / 2
        let scale = min(halfW / vw, h / vh)
        let figW = vw * scale, figH = vh * scale
        let dy = (h - figH) / 2
        let front = FigurePlacement(scale: scale, dx: (halfW - figW) / 2, dy: dy)
        let back = FigurePlacement(scale: scale, dx: halfW + figureGap + (halfW - figW) / 2, dy: dy)
        return (front, back)
    } else {
        let halfH = (h - figureGap) / 2
        let scale = min(w / vw, halfH / vh)
        let figW = vw * scale, figH = vh * scale
        let dx = (w - figW) / 2
        let front = FigurePlacement(scale: scale, dx: dx, dy: (halfH - figH) / 2)
        let back = FigurePlacement(scale: scale, dx: dx, dy: halfH + figureGap + (halfH - figH) / 2)
        return (front, back)
    }
}

// MARK: - 主视图

struct MuscleMapView: View {
    let highlights: [String: Intensity]
    var showLabelOnTap: Bool = true

    @State private var tappedName: String?

    var body: some View {
        GeometryReader { geo in
            let sideBySide = geo.size.width >= 260
            let layout = placements(geo.size.width, geo.size.height, sideBySide: sideBySide)

            ZStack(alignment: .top) {
                Canvas { ctx, _ in
                    drawFigure(ctx, MuscleGeometry.frontPaths, layout.front)
                    drawFigure(ctx, MuscleGeometry.backPaths, layout.back)
                }

                if showLabelOnTap, let name = tappedName {
                    Text(name)
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(MuscleColors.primaryFill))
                        .padding(.top, 4)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                guard showLabelOnTap else { return }
                let slug = hitTest(MuscleGeometry.frontPaths, layout.front, location)
                    ?? hitTest(MuscleGeometry.backPaths, layout.back, location)
                tappedName = slug.flatMap { MuscleMap.nameCN[$0] }
            }
        }
    }

    /// 先画未命中（底色），再画辅练，最后画主练，保证高亮压在最上层。
    private func drawFigure(_ ctx: GraphicsContext, _ paths: [String: Path], _ pl: FigurePlacement) {
        let t = pl.transform
        func pass(_ filter: (Intensity?) -> Bool, _ fill: Color, _ stroke: Color) {
            for (slug, path) in paths where filter(highlights[slug]) {
                let tp = path.applying(t)
                ctx.fill(tp, with: .color(fill))
                ctx.stroke(tp, with: .color(stroke), lineWidth: strokeViewbox * pl.scale)
            }
        }
        pass({ $0 == nil }, MuscleColors.baseFill, MuscleColors.baseStroke)
        pass({ $0 == .secondary }, MuscleColors.secondaryFill, MuscleColors.secondaryStroke)
        pass({ $0 == .primary }, MuscleColors.primaryFill, MuscleColors.primaryStroke)
    }

    /// 命中测试：优先返回高亮的肌肉，否则返回任意命中的有名肌肉。
    private func hitTest(_ paths: [String: Path], _ pl: FigurePlacement, _ point: CGPoint) -> String? {
        let t = pl.transform
        var fallback: String?
        for (slug, path) in paths {
            if path.applying(t).contains(point) {
                if highlights[slug] != nil { return slug }
                if fallback == nil, MuscleMap.nameCN[slug] != nil { fallback = slug }
            }
        }
        return fallback
    }
}

// MARK: - 图例：● 主练 / ● 辅练 / ○ 未练

struct MuscleLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            item(MuscleColors.primaryFill, border: nil, "主练")
            item(MuscleColors.secondaryFill, border: nil, "辅练")
            item(MuscleColors.baseFill, border: MuscleColors.baseStroke, "未练")
        }
    }

    private func item(_ color: Color, border: Color?, _ label: String) -> some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().fill(color)
                if let border { Circle().strokeBorder(border, lineWidth: 1) }
            }
            .frame(width: 12, height: 12)
            Text(label).font(.caption).foregroundStyle(Color.fitSecondaryText)
        }
    }
}

// MARK: - 激活肌群中文名 chips

struct ActivatedMuscleChips: View {
    let highlights: [String: Intensity]

    var body: some View {
        let names = activatedMuscleNames(highlights)
        if !names.isEmpty {
            FlowLayout(spacing: 8) {
                ForEach(names, id: \.name) { item in
                    let isPrimary = item.intensity == .primary
                    Text(item.name)
                        .font(.caption)
                        .fontWeight(isPrimary ? .semibold : .medium)
                        .foregroundStyle(isPrimary ? Color.white : MuscleColors.chipSecondaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(isPrimary ? MuscleColors.primaryFill : MuscleColors.secondaryFill)
                        )
                }
            }
        }
    }
}

// MARK: - 简易流式布局（自动换行的 chips 容器）

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
