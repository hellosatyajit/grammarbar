import AppKit

@MainActor
final class ShortcutMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var rightCommandDown = false
    private var rightOptionDown = false
    private var chordFired = false
    private var shortcut: Shortcut = .defaultShortcut
    var onTrigger: (() -> Void)?

    func start(shortcut: Shortcut) {
        self.shortcut = shortcut
        stop()
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
            return event
        }
    }

    func update(_ shortcut: Shortcut) { self.shortcut = shortcut }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handle(_ event: NSEvent) {
        if shortcut.rightModifierChord, event.type == .flagsChanged {
            if event.keyCode == 54 { rightCommandDown = event.modifierFlags.contains(.command) }
            if event.keyCode == 61 { rightOptionDown = event.modifierFlags.contains(.option) }
            if rightCommandDown && rightOptionDown && !chordFired {
                chordFired = true
                onTrigger?()
            }
            if !rightCommandDown || !rightOptionDown { chordFired = false }
            return
        }
        guard !shortcut.rightModifierChord, event.type == .keyDown, !event.isARepeat,
              event.keyCode == shortcut.keyCode else { return }
        let normalized = event.modifierFlags.intersection([.command, .option, .shift, .control]).rawValue
        if normalized == shortcut.modifiers { onTrigger?() }
    }
}
