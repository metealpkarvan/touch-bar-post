import AppKit
import PostCore

/// AppKit buttons deliver mouse and physical Touch Bar taps using the same actions.
final class StampButton: NSButton {
    var card: Card? { didSet { elapsed = 0; needsDisplay = true } }
    var concealed = false
    var language: Language = .tr
    var elapsed: Double = 0
    var animated = false
    override func draw(_ dirtyRect: NSRect) {
        let ink = concealed ? NSColor.postMuted : (card?.ink.color ?? Ink.aqua.color)
        ink.withAlphaComponent(0.16).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7).fill()
        let text: String
        if concealed { text = tr(language,"Metin gizli · Şerit menüsünden aç","Text hidden · Show it from the Şerit menu") }
        else if let card = card { text = Archive.oneLine(card.title + (card.body.isEmpty ? "" : "   ·   " + card.body)) }
        else { text = tr(language,"Bir not bırak. Şeridin hazır.","Leave a note. Your strip is ready.") }
        let size: CGFloat = bounds.height > 38 ? 16 : 12
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: .medium), .foregroundColor: NSColor.postWhite]
        let mark = concealed ? "○" : (card?.kind.mark ?? "✎")
        (mark as NSString).draw(at: NSPoint(x: 9, y: (bounds.height - size - 3) / 2), withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .bold), .foregroundColor: ink])
        let width = (text as NSString).size(withAttributes: attributes).width
        let space = max(1, bounds.width - 43)
        var offset: CGFloat = 0
        if animated && !concealed && width > space {
            let travel = Double(width + 40) / 24
            let phase = elapsed.truncatingRemainder(dividingBy: travel + 2)
            offset = CGFloat(max(0, phase - 2) * 24)
        }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: NSRect(x: 32, y: 0, width: space, height: bounds.height)).addClip()
        (text as NSString).draw(at: NSPoint(x: 32 - offset, y: (bounds.height - size - 3) / 2), withAttributes: attributes)
        if offset > 0 { (text as NSString).draw(at: NSPoint(x: 32 + width + 40 - offset, y: (bounds.height - size - 3) / 2), withAttributes: attributes) }
        NSGraphicsContext.restoreGraphicsState()
    }
}

final class RailView: NSView {
    let stamp = StampButton()
    let previous = NSButton(), next = NSButton(), act = NSButton()
    var onPrevious: (() -> Void)?, onNext: (() -> Void)?, onOpen: (() -> Void)?, onAction: (() -> Void)?
    override init(frame: NSRect) {
        super.init(frame: frame)
        for control in [previous, next, stamp, act] {
            control.target = self; control.isBordered = false; control.bezelStyle = .rounded
            control.font = .systemFont(ofSize: 13, weight: .bold); addSubview(control)
        }
        previous.title = "‹"; next.title = "›"
        previous.action = #selector(previousTap); next.action = #selector(nextTap)
        stamp.action = #selector(openTap); act.action = #selector(actionTap)
        stamp.setAccessibilityRole(.button)
        layoutButtons()
    }
    required init?(coder: NSCoder) { fatalError("Programmatic view") }
    override func draw(_ dirtyRect: NSRect) { NSColor.black.setFill(); NSBezierPath(roundedRect:bounds,xRadius:8,yRadius:8).fill() }
    override func layout() { super.layout(); layoutButtons() }
    func layoutButtons() {
        let side: CGFloat = bounds.height > 38 ? 34 : 27
        let action: CGFloat = bounds.height > 38 ? 84 : 65
        previous.frame = NSRect(x: 0, y: 0, width: side, height: bounds.height)
        stamp.frame = NSRect(x: side, y: 0, width: max(1, bounds.width - side * 2 - action - 9), height: bounds.height)
        next.frame = NSRect(x: bounds.width - side - action - 4, y: 0, width: side, height: bounds.height)
        act.frame = NSRect(x: bounds.width - action, y: 0, width: action, height: bounds.height)
    }
    func update(card: Card?, privacy: Bool, motion: Bool, language: Language) {
        if stamp.card != card { stamp.card = card }
        stamp.concealed = privacy; stamp.language = language
        stamp.animated = card?.kind == .announcement && motion && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        stamp.needsDisplay = true
        act.title = card?.kind == .reminder ? "✓" : tr(language,"Kopyala","Copy")
        act.isEnabled = card != nil && !privacy
        stamp.isEnabled = !privacy
        previous.setAccessibilityLabel(tr(language,"Önceki kart","Previous card"))
        next.setAccessibilityLabel(tr(language,"Sonraki kart","Next card"))
        act.setAccessibilityLabel(card?.kind == .reminder ? tr(language,"Hatırlatmayı tamamla","Complete reminder") : tr(language,"Notu panoya kopyala","Copy note to clipboard"))
        stamp.setAccessibilityLabel(privacy ? tr(language,"Perde kapalı","Curtain closed") : (card?.title ?? tr(language,"Yeni bir not oluştur","Create a note")))
    }
    func animate(delta: Double) { if stamp.animated { stamp.elapsed += delta; stamp.needsDisplay = true } }
    @objc private func previousTap() { onPrevious?() }
    @objc private func nextTap() { onNext?() }
    @objc private func openTap() { onOpen?() }
    @objc private func actionTap() { onAction?() }
}
