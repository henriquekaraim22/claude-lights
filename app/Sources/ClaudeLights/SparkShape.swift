import SwiftUI

/// The Claude Lights icon: a single 4-point sparkle. Never changes shape,
/// only color (see AggregatedStatus.color). Traced directly from the
/// user's own assets/spark.svg (24x24 viewBox), not an approximation.
struct SparkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scale = min(rect.width, rect.height) / 24
        let offsetX = rect.minX + (rect.width - 24 * scale) / 2
        let offsetY = rect.minY + (rect.height - 24 * scale) / 2

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: offsetX + x * scale, y: offsetY + y * scale)
        }

        path.move(to: pt(12, 2))
        path.addCurve(to: pt(22, 12), control1: pt(12.0039, 7.52123), control2: pt(16.4788, 11.9961))
        path.addCurve(to: pt(12, 22), control1: pt(16.4788, 12.0039), control2: pt(12.0039, 16.4788))
        path.addCurve(to: pt(2, 12), control1: pt(11.9961, 16.4788), control2: pt(7.52123, 12.0039))
        path.addCurve(to: pt(12, 2), control1: pt(7.52123, 11.9961), control2: pt(11.9961, 7.52123))
        path.closeSubpath()
        return path
    }
}
