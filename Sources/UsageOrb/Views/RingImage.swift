import AppKit

/// Draws one provider's menu bar ring with its logo inside. Shape carries meaning as well as colour:
/// critical fills the ring, a dashed track means stale, a dashed circle means unknown.
enum RingImage {
    static let size = NSSize(width: 20, height: 20)

    static func image(for state: RingState, provider: ProviderID?) -> NSImage {
        let template: Bool = switch state {
        case .unknown, .value(_, .normal, _, _): true
        case .value: false
        }
        let image = NSImage(size: size, flipped: false) { rect in
            draw(state, logo: provider?.logo, in: rect, template: template)
            return true
        }
        image.isTemplate = template
        return image
    }

    private static func draw(_ state: RingState, logo: NSImage?, in rect: NSRect, template: Bool) {
        let lineWidth: CGFloat = 1.8
        let circle = rect.insetBy(dx: 1.2, dy: 1.2)
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let ink: NSColor = template ? .black : .labelColor
        let logoRect = rect.insetBy(dx: 5, dy: 5)
        let track = NSBezierPath(ovalIn: circle)
        track.lineWidth = lineWidth

        guard case .value(let percent, let level, _, let isStale) = state else {
            ink.withAlphaComponent(0.55).setStroke()
            track.setLineDash([1.8, 1.8], count: 2, phase: 0)
            track.stroke()
            logo?.drawTinted(in: logoRect, color: ink.withAlphaComponent(0.55))
            return
        }

        if level == .critical {
            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).fill()
            logo?.drawTinted(in: logoRect, color: .white)
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
        logo?.drawTinted(in: logoRect, color: ink.withAlphaComponent(isStale ? 0.55 : 1))
    }
}

extension NSImage {
    /// Draws the image's shape filled with one colour.
    func drawTinted(in rect: NSRect, color: NSColor) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.beginTransparencyLayer(in: rect, auxiliaryInfo: nil)
        draw(in: rect)
        color.setFill()
        rect.fill(using: .sourceAtop)
        context.endTransparencyLayer()
        context.restoreGState()
    }
}

extension ProviderID {
    /// The provider's logo from Resources/ProviderLogos, as a template image.
    var logo: NSImage? { LogoCache.images[self] }
}

private enum LogoCache {
    // Loaded once and only read afterwards.
    nonisolated(unsafe) static let images: [ProviderID: NSImage] = Dictionary(
        uniqueKeysWithValues: ProviderID.allCases.compactMap { id in
            guard let url = Bundle.main.url(forResource: id.rawValue, withExtension: "svg"),
                  let image = NSImage(contentsOf: url) else { return nil }
            image.isTemplate = true
            return (id, image)
        })
}
