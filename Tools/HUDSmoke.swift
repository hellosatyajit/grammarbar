import AppKit

@main
enum HUDSmoke {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let hud = HUDController()
        hud.show(.working)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { hud.show(.success) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { hud.show(.error("Test error")) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { application.terminate(nil) }
        application.run()
    }
}
