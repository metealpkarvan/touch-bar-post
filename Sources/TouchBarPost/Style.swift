import AppKit
import PostCore

func tr(_ language: Language, _ turkish: String, _ english: String) -> String { language == .tr ? turkish : english }
extension Scene {
    func name(_ l: Language) -> String { switch self { case .desk: return tr(l,"Masam","Desk"); case .pause: return tr(l,"Mola","Break"); case .home: return tr(l,"Ev","Home") } }
}
extension CardKind {
    func name(_ l: Language) -> String { switch self { case .announcement: return tr(l,"Duyuru","Announcement"); case .note: return tr(l,"Not","Note"); case .reminder: return tr(l,"Hatırlatma","Reminder") } }
    var mark: String { switch self { case .announcement: return "↗"; case .note: return "✎"; case .reminder: return "◷" } }
}
extension Ink {
    var color: NSColor { switch self {
    case .amber: return NSColor(calibratedRed: 1, green: 0.72, blue: 0.32, alpha: 1)
    case .aqua: return NSColor(calibratedRed: 0.37, green: 0.86, blue: 0.84, alpha: 1)
    case .rose: return NSColor(calibratedRed: 0.99, green: 0.55, blue: 0.67, alpha: 1)
    case .lime: return NSColor(calibratedRed: 0.78, green: 0.91, blue: 0.52, alpha: 1)
    } }
    func name(_ l: Language) -> String { switch self { case .amber: return tr(l,"Kehribar","Amber"); case .aqua: return tr(l,"Turkuaz","Aqua"); case .rose: return tr(l,"Gül","Rose"); case .lime: return tr(l,"Filiz","Lime") } }
}
extension NSColor {
    static let postBackground = NSColor(calibratedRed: 0.065, green: 0.085, blue: 0.105, alpha: 1)
    static let postPanel = NSColor(calibratedRed: 0.10, green: 0.125, blue: 0.15, alpha: 1)
    static let postWhite = NSColor(calibratedRed: 0.93, green: 0.94, blue: 0.91, alpha: 1)
    static let postMuted = NSColor(calibratedRed: 0.62, green: 0.69, blue: 0.72, alpha: 1)
}
final class Canvas: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ rect: NSRect) { NSColor.postBackground.setFill(); bounds.fill() }
}
final class Panel: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ rect: NSRect) {
        NSColor.postPanel.setFill(); NSBezierPath(roundedRect: bounds, xRadius: 16, yRadius: 16).fill()
        NSColor.postMuted.withAlphaComponent(0.16).setStroke()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 16, yRadius: 16).stroke()
    }
}
func label(_ text: String, _ frame: NSRect, size: CGFloat = 13, color: NSColor = .postWhite, weight: NSFont.Weight = .regular, in parent: NSView) -> NSTextField {
    let field = NSTextField(wrappingLabelWithString: text); field.frame = frame
    field.font = .systemFont(ofSize: size, weight: weight); field.textColor = color
    field.maximumNumberOfLines = 0; parent.addSubview(field); return field
}
func button(_ text: String, _ frame: NSRect, target: AnyObject, action: Selector, in parent: NSView) -> NSButton {
    let control = NSButton(title: text, target: target, action: action); control.frame = frame
    control.bezelStyle = .rounded; control.font = .systemFont(ofSize: 12, weight: .medium)
    parent.addSubview(control); return control
}
