import CoreGraphics
import SwiftUI

/// 把 SVG path 的 "d" 字符串解析成 SwiftUI `Path`。
///
/// iOS / SwiftUI 没有内置的 SVG 路径解析（Android 用 PathParser），所以这里自己实现一个。
/// 支持的指令：M/m L/l H/h V/v C/c S/s Q/q T/t A/a Z/z。
/// 椭圆弧 A/a 用 SVG 规范附录 F.6 的「端点参数 → 中心参数」算法，再以 cubic bezier 逼近。
/// 坐标系与 SVG 一致（y 向下），SwiftUI Path 同为 y 向下，无需翻转。
enum SVGPath {

    static func parse(_ d: String) -> Path {
        var path = Path()
        var r = Reader(d)

        var current = CGPoint.zero      // 当前点
        var start = CGPoint.zero        // 子路径起点（Z 回到这里）
        var cmd: Character = " "        // 当前（或隐式重复的）指令
        var lastCubicCtrl: CGPoint?     // 上一条三次曲线的第二控制点（S/s 反射用）
        var lastQuadCtrl: CGPoint?      // 上一条二次曲线的控制点（T/t 反射用）

        while true {
            r.skipSeparators()
            guard let c = r.peek() else { break }

            if c.isLetter {
                cmd = c
                r.advance()
                if cmd == "Z" || cmd == "z" {
                    path.closeSubpath()
                    current = start
                    lastCubicCtrl = nil
                    lastQuadCtrl = nil
                    continue
                }
            } else if cmd == " " {
                // 没有指令却出现数字：异常，跳过一个字符避免死循环
                r.advance()
                continue
            }

            switch cmd {
            case "M", "m":
                var p = r.point()
                if cmd == "m" { p = current + p }
                path.move(to: p)
                current = p
                start = p
                lastCubicCtrl = nil
                lastQuadCtrl = nil
                cmd = (cmd == "m") ? "l" : "L"   // 后续隐式坐标按 lineto 处理

            case "L", "l":
                var p = r.point()
                if cmd == "l" { p = current + p }
                path.addLine(to: p)
                current = p
                lastCubicCtrl = nil
                lastQuadCtrl = nil

            case "H", "h":
                let x = r.number()
                let p = (cmd == "h") ? CGPoint(x: current.x + x, y: current.y)
                                     : CGPoint(x: x, y: current.y)
                path.addLine(to: p)
                current = p
                lastCubicCtrl = nil
                lastQuadCtrl = nil

            case "V", "v":
                let yv = r.number()
                let p = (cmd == "v") ? CGPoint(x: current.x, y: current.y + yv)
                                     : CGPoint(x: current.x, y: yv)
                path.addLine(to: p)
                current = p
                lastCubicCtrl = nil
                lastQuadCtrl = nil

            case "C", "c":
                var c1 = r.point(), c2 = r.point(), p = r.point()
                if cmd == "c" { c1 = current + c1; c2 = current + c2; p = current + p }
                path.addCurve(to: p, control1: c1, control2: c2)
                current = p
                lastCubicCtrl = c2
                lastQuadCtrl = nil

            case "S", "s":
                var c2 = r.point(), p = r.point()
                if cmd == "s" { c2 = current + c2; p = current + p }
                let c1 = reflect(lastCubicCtrl, around: current)
                path.addCurve(to: p, control1: c1, control2: c2)
                current = p
                lastCubicCtrl = c2
                lastQuadCtrl = nil

            case "Q", "q":
                var cc = r.point(), p = r.point()
                if cmd == "q" { cc = current + cc; p = current + p }
                path.addQuadCurve(to: p, control: cc)
                current = p
                lastQuadCtrl = cc
                lastCubicCtrl = nil

            case "T", "t":
                var p = r.point()
                if cmd == "t" { p = current + p }
                let cc = reflect(lastQuadCtrl, around: current)
                path.addQuadCurve(to: p, control: cc)
                current = p
                lastQuadCtrl = cc
                lastCubicCtrl = nil

            case "A", "a":
                let rx = r.number(), ry = r.number(), rot = r.number()
                let large = r.flag(), sweep = r.flag()
                var p = r.point()
                if cmd == "a" { p = current + p }
                appendArc(to: &path, from: current, rx: rx, ry: ry,
                          xAxisRotationDeg: rot, largeArc: large, sweep: sweep, to: p)
                current = p
                lastCubicCtrl = nil
                lastQuadCtrl = nil

            default:
                // 未知指令，跳过一个 token 防止死循环
                r.advance()
            }
        }

        return path
    }

    // MARK: - 控制点反射（S/T 平滑曲线）

    private static func reflect(_ ctrl: CGPoint?, around pt: CGPoint) -> CGPoint {
        guard let ctrl else { return pt }
        return CGPoint(x: 2 * pt.x - ctrl.x, y: 2 * pt.y - ctrl.y)
    }

    // MARK: - 椭圆弧 → cubic bezier（SVG 规范 F.6 实现）

    private static func appendArc(
        to path: inout Path,
        from p0: CGPoint,
        rx rx0: CGFloat,
        ry ry0: CGFloat,
        xAxisRotationDeg: CGFloat,
        largeArc: Bool,
        sweep: Bool,
        to p1: CGPoint
    ) {
        if p0 == p1 { return }
        var rx = abs(rx0), ry = abs(ry0)
        if rx < 1e-6 || ry < 1e-6 {
            path.addLine(to: p1)
            return
        }

        let phi = xAxisRotationDeg * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)

        // 步骤 1：把终点平移、旋转到「弧的局部坐标」
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1p =  cosPhi * dx + sinPhi * dy
        let y1p = -sinPhi * dx + cosPhi * dy

        // 半径修正（F.6.6）
        var rxs = rx * rx, rys = ry * ry
        let lambda = (x1p * x1p) / rxs + (y1p * y1p) / rys
        if lambda > 1 {
            let s = sqrt(lambda)
            rx *= s; ry *= s
            rxs = rx * rx; rys = ry * ry
        }

        // 步骤 2：求圆心（局部坐标）
        let sign: CGFloat = (largeArc != sweep) ? 1 : -1
        var num = rxs * rys - rxs * y1p * y1p - rys * x1p * x1p
        if num < 0 { num = 0 }
        let den = rxs * y1p * y1p + rys * x1p * x1p
        let coef = sign * sqrt(num / max(den, 1e-12))
        let cxp =  coef * (rx * y1p / ry)
        let cyp = -coef * (ry * x1p / rx)

        // 步骤 3：转回原坐标系
        let cx = cosPhi * cxp - sinPhi * cyp + (p0.x + p1.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (p0.y + p1.y) / 2

        // 步骤 4：起始角与扫掠角
        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let dot = ux * vx + uy * vy
            let len = sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy))
            var a = acos(min(max(len == 0 ? 1 : dot / len, -1), 1))
            if ux * vy - uy * vx < 0 { a = -a }
            return a
        }
        let ux = (x1p - cxp) / rx, uy = (y1p - cyp) / ry
        let vx = (-x1p - cxp) / rx, vy = (-y1p - cyp) / ry
        let theta1 = angle(1, 0, ux, uy)
        var dTheta = angle(ux, uy, vx, vy)
        if !sweep && dTheta > 0 { dTheta -= 2 * .pi }
        if sweep && dTheta < 0 { dTheta += 2 * .pi }

        // 步骤 5：按 ≤90° 分段，每段用一条 cubic bezier 逼近
        let segments = max(Int(ceil(abs(dTheta) / (.pi / 2))), 1)
        let delta = dTheta / CGFloat(segments)
        let t = 4.0 / 3.0 * tan(delta / 4)

        func point(_ a: CGFloat) -> CGPoint {
            let x = rx * cos(a), y = ry * sin(a)
            return CGPoint(x: cosPhi * x - sinPhi * y + cx,
                           y: sinPhi * x + cosPhi * y + cy)
        }
        func deriv(_ a: CGFloat) -> CGPoint {
            let x = -rx * sin(a), y = ry * cos(a)
            return CGPoint(x: cosPhi * x - sinPhi * y,
                           y: sinPhi * x + cosPhi * y)
        }

        var a0 = theta1
        for _ in 0..<segments {
            let a1 = a0 + delta
            let pt0 = point(a0), pt1 = point(a1)
            let d0 = deriv(a0), d1 = deriv(a1)
            let c1 = CGPoint(x: pt0.x + t * d0.x, y: pt0.y + t * d0.y)
            let c2 = CGPoint(x: pt1.x - t * d1.x, y: pt1.y - t * d1.y)
            path.addCurve(to: pt1, control1: c1, control2: c2)
            a0 = a1
        }
    }
}

// MARK: - 词法扫描器

private struct Reader {
    private let chars: [Character]
    private var i = 0

    init(_ s: String) { chars = Array(s) }

    func peek() -> Character? { i < chars.count ? chars[i] : nil }
    mutating func advance() { if i < chars.count { i += 1 } }

    mutating func skipSeparators() {
        while i < chars.count {
            let c = chars[i]
            if c == " " || c == "," || c == "\n" || c == "\t" || c == "\r" {
                i += 1
            } else {
                break
            }
        }
    }

    /// 读一个浮点数（含正负号、小数、科学计数法）
    mutating func number() -> CGFloat {
        skipSeparators()
        var s = ""
        if let c = peek(), c == "+" || c == "-" { s.append(c); i += 1 }
        while let c = peek(), c.isASCIIDigit { s.append(c); i += 1 }
        if let c = peek(), c == "." {
            s.append("."); i += 1
            while let c = peek(), c.isASCIIDigit { s.append(c); i += 1 }
        }
        if let c = peek(), c == "e" || c == "E" {
            s.append(c); i += 1
            if let c = peek(), c == "+" || c == "-" { s.append(c); i += 1 }
            while let c = peek(), c.isASCIIDigit { s.append(c); i += 1 }
        }
        return CGFloat(Double(s) ?? 0)
    }

    /// 读一个 x,y 坐标对
    mutating func point() -> CGPoint {
        let x = number()
        let y = number()
        return CGPoint(x: x, y: y)
    }

    /// 读弧线的标志位（large-arc / sweep）。SVG 里标志位是单字符 0/1，
    /// 可能不与后续数字用空格分隔（如 "0 012.89" = flag0,flag1,then 2.89）。
    mutating func flag() -> Bool {
        skipSeparators()
        guard let c = peek() else { return false }
        i += 1
        return c == "1"
    }
}

private extension Character {
    var isASCIIDigit: Bool { self >= "0" && self <= "9" }
}

private func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}
