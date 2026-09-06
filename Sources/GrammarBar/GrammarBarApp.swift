import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct GrammarBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings: AppSettings
    @StateObject private var controller: AppController

    init() {
        let settings = AppSettings()
        _settings = StateObject(wrappedValue: settings)
        _controller = StateObject(wrappedValue: AppController(settings: settings))
    }

    var body: some Scene {
        MenuBarExtra("GrammarBar", systemImage: controller.isWorking ? "text.badge.ellipsis" : "textformat") {
            Button("Fix Grammar Now") { controller.fixGrammar() }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            Divider()
            Button("Settings…") { controller.showSettings() }
            Button("Evals Dashboard…") { controller.showEvals() }
            Button("About GrammarBar") { NSApp.orderFrontStandardAboutPanel(nil); NSApp.activate(ignoringOtherApps: true) }
            Divider()
            Button("Quit GrammarBar") { NSApp.terminate(nil) }
        }
    }
}
