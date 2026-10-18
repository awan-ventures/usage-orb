import AppKit

/// Draws one provider's menu bar ring with its monogram inside. Shape carries meaning as well as colour:
/// critical fills the ring, a dashed track means stale, a dashed circle means unknown.
enum RingImage {
    static let size = NSSize(width: 18, height: 18)

    static func image(for state: RingState, monogram: String) -> NSImage {
        let template: Bool = switch state {
        case .unknown, .value(_, .normal, _, _): true
        case .value: false
        }
        let image = NSImage(size: size, flipped: false) { rect in
            draw(state, monogram: monogram, in: rect, template: template)
            return true
        }
        image.isTemplate = template
        return image
    }

    private static func draw(_ state: RingState, monogram: String, in rect: NSRect, template: Bool) {
        let lineWidth: CGFloat = 2
        let circle = rect.insetBy(dx: 1.5, dy: 1.5)
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let ink: NSColor = template ? .black : .labelColor
        let track = NSBezierPath(ovalIn: circle)
        track.lineWidth = lineWidth

        guard case .value(let percent, let level, _, let isStale) = state else {
            ink.withAlphaComponent(0.55).setStroke()
            track.setLineDash([1.8, 1.8], count: 2, phase: 0)
            track.stroke()
            letter(monogram, at: center, color: ink.withAlphaComponent(0.55))
            return
        }

        if level == .critical {
            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).fill()
            letter(monogram, at: center, color: .white)
            return
        }

        let accent: NSColor = level == .warning ? .systemOrange : ink
        ink.withAlphaComponent(0.25).setStroke()
        if isStale { track.setLineDash([1.5, 1.5], count: 2, phase: 0) }
        track.stroke()

        let fraction = min(max(percent / 100, 0), 1)
        if fraction > 0 {
            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: circle.width / 2, startAngle: 90,
                          endAngle: 90 - 360 * fraction, clockwise: true)
            arc.lineWidth = lineWidth
            arc.lineCapStyle = .round
            accent.withAlphaComponent(isStale ? 0.45 : 1).setStroke()
            arc.stroke()
        }
        letter(monogram, at: center, color: ink.withAlphaComponent(isStale ? 0.55 : 1))
    }

    private static func letter(_ text: String, at center: NSPoint, color: NSColor) {
        let font = NSFont.systemFont(ofSize: 8.5, weight: .heavy)
        let rounded = font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 8.5) } ?? font
        let string = NSAttributedString(string: text, attributes: [.font: rounded, .foregroundColor: color])
        let size = string.size()
        string.draw(at: NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2 + 0.3))
    }
}
