import AppKit

@MainActor
final class HUDController {
    private let panel: NSPanel
    private let hudView: HUDContentView
    private var presentationID = 0

    init() {
        let frame = NSRect(x: 0, y: 0, width: 360, height: 52)
        hudView = HUDContentView(frame: frame)
        panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hudView
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
    }

    func show(_ state: HUDState) {
        presentationID += 1
        hudView.update(state)
        position()
        panel.orderFrontRegardless()
    }

    func hide(after delay: TimeInterval = 0) {
        let expectedID = presentationID
        guard delay > 0 else {
            panel.orderOut(nil)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.presentationID == expectedID else { return }
            self.panel.orderOut(nil)
        }
    }

    private func position() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        panel.setFrameOrigin(NSPoint(
            x: screen.visibleFrame.midX - panel.frame.width / 2,
            y: screen.visibleFrame.minY + 32
        ))
    }
}

enum HUDState {
    case working
    case success
    case error(String)
}

/// Fixed AppKit frames avoid NSHostingView resize callbacks during a window layout pass.
@MainActor
private final class HUDContentView: NSView {
    private let spinner = NSProgressIndicator()
    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.frame = NSRect(x: 20, y: 17, width: 18, height: 18)
        spinner.appearance = NSAppearance(named: .darkAqua)

        icon.frame = NSRect(x: 21, y: 18, width: 16, height: 16)
        icon.contentTintColor = .white
        icon.imageScaling = .scaleProportionallyDown

        label.frame = NSRect(x: 50, y: 16, width: 288, height: 20)
        label.textColor = .white
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.lineBreakMode = .byTruncatingTail

        addSubview(spinner)
        addSubview(icon)
        addSubview(label)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let rect = bounds.insetBy(dx: 1, dy: 4)
        let path = NSBezierPath(roundedRect: rect, xRadius: 22, yRadius: 22)
        NSColor.black.setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.24).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    func update(_ state: HUDState) {
        switch state {
        case .working:
            label.stringValue = "Fixing grammar…"
            icon.isHidden = true
            spinner.isHidden = false
            spinner.startAnimation(nil)
        case .success:
            label.stringValue = "Grammar fixed"
            spinner.stopAnimation(nil)
            spinner.isHidden = true
            icon.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Success")
            icon.isHidden = false
        case .error(let message):
            label.stringValue = message
            spinner.stopAnimation(nil)
            spinner.isHidden = true
            icon.image = NSImage(systemSymbolName: "exclamationmark", accessibilityDescription: "Error")
            icon.isHidden = false
        }
        needsDisplay = true
    }
}
