import AppKit

/// Draws the menu bar ring. The shape carries meaning as well as colour:
/// a dot appears inside at warning and fills at critical, a dashed track means stale, a dashed circle means unknown.
enum RingImage {
    static let size = NSSize(width: 18, height: 18)

    static func image(for state: RingState) -> NSImage {
        let template: Bool
        if case .value(_, .normal, _, _) = state { template = true } else { template = state.isUnknown }

        let image = NSImage(size: size, flipped: false) { rect in
            draw(state, in: rect, template: template)
            return true
        }
        image.isTemplate = template
        return image
    }

    private static func draw(_ state: RingState, in rect: NSRect, template: Bool) {
        let lineWidth: CGFloat = 2.4
        let circle = rect.insetBy(dx: 2, dy: 2)
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let radius = circle.width / 2
        let ink = NSColor.black

        let track = NSBezierPath(ovalIn: circle)
        track.lineWidth = lineWidth

        guard case .value(let percent, let level, _, let isStale) = state else {
            ink.withAlphaComponent(0.7).setStroke()
            track.setLineDash([2, 2.2], count: 2, phase: 0)
            track.stroke()
            return
        }

        let accent: NSColor = switch level {
        case .normal: ink
        case .warning: .systemOrange
        case .critical: .systemRed
        }
        (template ? ink.withAlphaComponent(0.28) : NSColor.secondaryLabelColor.withAlphaComponent(0.45)).setStroke()
        if isStale { track.setLineDash([1.6, 1.6], count: 2, phase: 0) }
        track.stroke()

        let fraction = min(max(percent / 100, 0), 1)
        if fraction > 0 {
            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: radius, startAngle: 90,
                          endAngle: 90 - 360 * fraction, clockwise: true)
            arc.lineWidth = lineWidth
            arc.lineCapStyle = fraction < 1 ? .round : .butt
            accent.withAlphaComponent(isStale ? 0.5 : 1).setStroke()
            arc.stroke()
        }

        switch level {
        case .normal: break
        case .warning:
            let dot = NSBezierPath(ovalIn: NSRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4))
            accent.setFill()
            dot.fill()
        case .critical:
            let dot = NSBezierPath(ovalIn: NSRect(x: center.x - 3.6, y: center.y - 3.6, width: 7.2, height: 7.2))
            accent.setFill()
            dot.fill()
        }
    }
}

extension RingState {
    var isUnknown: Bool { if case .unknown = self { true } else { false } }

    var percent: Double? { if case .value(let percent, _, _, _) = self { percent } else { nil } }
}
