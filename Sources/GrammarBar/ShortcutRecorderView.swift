import AppKit
import SwiftUI

struct ShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: Shortcut
    @Binding var recording: Bool

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.onRecord = { shortcut in
            self.shortcut = shortcut
            self.recording = false
        }
        view.recording = recording
        return view
    }
    func updateNSView(_ view: RecorderNSView, context: Context) {
        view.recording = recording
        view.onRecord = { shortcut in self.shortcut = shortcut; self.recording = false }
        if recording { DispatchQueue.main.async { view.window?.makeFirstResponder(view) } }
    }
}

final class RecorderNSView: NSView {
    var onRecord: ((Shortcut) -> Void)?
    var recording = false
    private var sawRightCommand = false
    private var sawRightOption = false
    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard recording else { return }
        if event.keyCode == 53 { return }
        let modifiers = event.modifierFlags.intersection([.command, .option, .shift, .control]).rawValue
        onRecord?(Shortcut(keyCode: event.keyCode, modifiers: modifiers, rightModifierChord: false))
    }

    override func flagsChanged(with event: NSEvent) {
        guard recording else { return }
        if event.keyCode == 54 && event.modifierFlags.contains(.command) { sawRightCommand = true }
        if event.keyCode == 61 && event.modifierFlags.contains(.option) { sawRightOption = true }
        if sawRightCommand && sawRightOption { onRecord?(.defaultShortcut) }
    }
}
