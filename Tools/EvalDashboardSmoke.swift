import AppKit
import SwiftUI

@main
enum EvalDashboardSmoke {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let settings = AppSettings()
        let hostingView = NSHostingView(rootView: EvalDashboardView(settings: settings))
        hostingView.sizingOptions = []
        hostingView.frame = NSRect(x: 0, y: 0, width: 920, height: 680)
        let window = NSWindow(contentRect: hostingView.frame, styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.contentView = hostingView
        window.orderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { application.terminate(nil) }
        application.run()
    }
}
