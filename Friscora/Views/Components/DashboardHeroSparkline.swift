//
//  DashboardHeroSparkline.swift
//  Friscora
//
//  Decorative sparkline for the dashboard hero card (fixed path, edge-to-edge).
//

import SwiftUI

/// SVG-equivalent path in a 340×44 viewBox, stretched horizontally; `chartHeight` scales the vertical draw area.
struct DashboardHeroSparkline: View {
    /// Rendered height (viewBox Y is always normalized to 44pt).
    var chartHeight: CGFloat = 44
    /// Hairline scales slightly when the chart is short.
    var lineStrokeWidth: CGFloat = 1.5
    /// Increment (e.g. from `DashboardView`) to replay the left-to-right draw-on; first load and tab return.
    var entranceTrigger: Int = 0

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var drawProgress: CGFloat = 0
    @State private var drawStartTask: Task<Void, Never>?

    private static let viewWidth: CGFloat = 340
    private static let viewBoxHeight: CGFloat = 44

    /// Portion of the trim window over which the terminal dot fades/scales in (after ~92% of the stroke).
    private static let terminalDotLeadInFraction: CGFloat = 0.08

    private static let linePoints: [CGPoint] = [
        CGPoint(x: 0, y: 38),
        CGPoint(x: 28, y: 32),
        CGPoint(x: 57, y: 28),
        CGPoint(x: 85, y: 22),
        CGPoint(x: 113, y: 18),
        CGPoint(x: 142, y: 24),
        CGPoint(x: 170, y: 14),
        CGPoint(x: 198, y: 10),
        CGPoint(x: 227, y: 16),
        CGPoint(x: 255, y: 8),
        CGPoint(x: 283, y: 4),
        CGPoint(x: 312, y: 10),
        CGPoint(x: 340, y: 6)
    ]

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let sx = w / Self.viewWidth
            let sy = h / Self.viewBoxHeight

            let topPath = Self.polylinePath(points: Self.linePoints, sx: sx, sy: sy)
            let fillPath = Self.filledAreaPath(points: Self.linePoints, sx: sx, sy: sy, bottomY: h)
            let fillRevealWidth = max(0, w * drawProgress)
            let dotLead = terminalDotVisual(reduceMotion: accessibilityReduceMotion)

            ZStack(alignment: .bottomLeading) {
                fillPath
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.22),
                                Color.white.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .mask {
                        Rectangle()
                            .frame(width: fillRevealWidth)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    }

                topPath
                    .trim(from: 0, to: drawProgress)
                    .stroke(
                        Color.white.opacity(0.88),
                        style: StrokeStyle(lineWidth: lineStrokeWidth, lineCap: .round, lineJoin: .round)
                    )

                if let last = Self.linePoints.last {
                    let cx = last.x * sx
                    let cy = last.y * sy
                    let r = max(2.2, min(4.5, 3 * min(sx, sy)))
                    Circle()
                        .fill(Color.white.opacity(0.95))
                        .frame(width: r * 2, height: r * 2)
                        .scaleEffect(dotLead.scale)
                        .opacity(dotLead.opacity)
                        .position(x: cx, y: cy)
                }
            }
            .frame(width: w, height: h, alignment: .bottomLeading)
        }
        .frame(height: chartHeight)
        .accessibilityHidden(true)
        .onChange(of: entranceTrigger) { _, _ in
            scheduleDrawOnAnimation()
        }
        .onDisappear {
            drawStartTask?.cancel()
            drawStartTask = nil
        }
    }

    private func terminalDotVisual(reduceMotion: Bool) -> (opacity: CGFloat, scale: CGFloat) {
        if reduceMotion { return (opacity: 1, scale: 1) }
        let t = (drawProgress - (1 - Self.terminalDotLeadInFraction)) / Self.terminalDotLeadInFraction
        let u = max(0, min(1, t))
        return (opacity: u, scale: 0.62 + 0.38 * u)
    }

    private func scheduleDrawOnAnimation() {
        drawStartTask?.cancel()
        if accessibilityReduceMotion {
            drawProgress = 1
            return
        }
        var resetTransaction = Transaction()
        resetTransaction.disablesAnimations = true
        withTransaction(resetTransaction) {
            drawProgress = 0
        }
        drawStartTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 60_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(AppAnimation.lineChartDraw) {
                drawProgress = 1
            }
        }
    }

    private static func polylinePath(points: [CGPoint], sx: CGFloat, sy: CGFloat) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: CGPoint(x: first.x * sx, y: first.y * sy))
        for pt in points.dropFirst() {
            p.addLine(to: CGPoint(x: pt.x * sx, y: pt.y * sy))
        }
        return p
    }

    private static func filledAreaPath(points: [CGPoint], sx: CGFloat, sy: CGFloat, bottomY: CGFloat) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: CGPoint(x: first.x * sx, y: first.y * sy))
        for pt in points.dropFirst() {
            p.addLine(to: CGPoint(x: pt.x * sx, y: pt.y * sy))
        }
        p.addLine(to: CGPoint(x: 340 * sx, y: bottomY))
        p.addLine(to: CGPoint(x: 0, y: bottomY))
        p.closeSubpath()
        return p
    }
}
