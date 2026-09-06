import AppKit
import SwiftUI

@main
enum SettingsSmoke {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let settings = AppSettings()
        settings.onboardingComplete = true
        let hostingView = NSHostingView(rootView: SettingsView(settings: settings, requestAccessibility: {}))
        hostingView.sizingOptions = []
        hostingView.frame = NSRect(x: 0, y: 0, width: 560, height: 520)
        let window = NSWindow(contentRect: hostingView.frame, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.contentView = hostingView
        window.orderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { settings.provider = .ollama }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { settings.model = "qwen3:0.6b" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { application.terminate(nil) }
        application.run()
    }
}
