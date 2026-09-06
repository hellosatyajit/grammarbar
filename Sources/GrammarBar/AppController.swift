import AppKit
import Combine
import SwiftUI

@MainActor
final class AppController: ObservableObject {
    let settings: AppSettings
    private let monitor = ShortcutMonitor()
    private let hud = HUDController()
    private let client = GrammarClient()
    private var cancellables: Set<AnyCancellable> = []
    private var settingsWindowController: NSWindowController?
    private var evalWindowController: NSWindowController?
    @Published private(set) var isWorking = false

    init(settings: AppSettings) {
        self.settings = settings
        monitor.onTrigger = { [weak self] in self?.fixGrammar() }
        monitor.start(shortcut: settings.shortcut)
        settings.$shortcut.dropFirst().sink { [weak self] in self?.monitor.update($0) }.store(in: &cancellables)
        if !settings.onboardingComplete {
            DispatchQueue.main.async { [weak self] in self?.showSettings() }
        }
    }

    func fixGrammar() {
        guard !isWorking else { return }
        let config = GrammarConfiguration(provider: settings.provider, model: settings.model,
            apiKey: settings.apiKey, ollamaURL: settings.ollamaURL, lmStudioURL: settings.lmStudioURL)
        isWorking = true
        hud.show(.working)
        Task {
            do {
                // Let a menu close and the previous editor regain focus before reading it.
                try? await Task.sleep(nanoseconds: 120_000_000)
                let snapshot = try await TextBridge.capture()
                let corrected = try await client.correct(snapshot.text, using: config)
                try await TextBridge.replace(snapshot, with: corrected)
                hud.show(.success)
                hud.hide(after: 1.2)
            } catch { show(error) }
            isWorking = false
        }
    }

    func requestAccessibility() { _ = TextBridge.requestAccessibility() }

    func showSettings() {
        if settingsWindowController == nil {
            let root = SettingsView(settings: settings) { [weak self] in self?.requestAccessibility() }
            let hostingView = NSHostingView(rootView: root)
            hostingView.sizingOptions = []
            hostingView.frame = NSRect(x: 0, y: 0, width: 560, height: 520)

            let window = NSWindow(
                contentRect: hostingView.frame,
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = settings.onboardingComplete ? "GrammarBar Settings" : "Welcome to GrammarBar"
            window.contentView = hostingView
            window.contentMinSize = NSSize(width: 560, height: 520)
            window.contentMaxSize = NSSize(width: 560, height: 520)
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindowController = NSWindowController(window: window)
        }
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showEvals() {
        if evalWindowController == nil {
            let hostingView = NSHostingView(rootView: EvalDashboardView(settings: settings))
            hostingView.sizingOptions = []
            hostingView.frame = NSRect(x: 0, y: 0, width: 920, height: 680)
            let window = NSWindow(
                contentRect: hostingView.frame,
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "GrammarBar Evals"
            window.contentView = hostingView
            window.contentMinSize = NSSize(width: 820, height: 560)
            window.isReleasedWhenClosed = false
            window.center()
            evalWindowController = NSWindowController(window: window)
        }
        evalWindowController?.showWindow(nil)
        evalWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func show(_ error: Error) {
        hud.show(.error(error.localizedDescription))
        hud.hide(after: 3.5)
    }
}
