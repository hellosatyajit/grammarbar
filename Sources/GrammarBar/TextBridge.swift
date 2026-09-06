import AppKit
import ApplicationServices

struct TextSnapshot: @unchecked Sendable {
    let element: AXUIElement?
    let text: String
    let isSelection: Bool
    let usesClipboard: Bool
}

enum TextBridgeError: LocalizedError {
    case accessibilityRequired
    case noTextField
    case replacementFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityRequired: return "Allow GrammarBar in System Settings → Privacy & Security → Accessibility."
        case .noTextField: return "Place the cursor in an editable text field and try again."
        case .replacementFailed: return "The app could read this field but could not replace its text."
        }
    }
}

@MainActor
enum TextBridge {
    static func requestAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func capture() async throws -> TextSnapshot {
        guard AXIsProcessTrusted() else { throw TextBridgeError.accessibilityRequired }
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let element: AXUIElement?
        if AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
           let focused {
            element = (focused as! AXUIElement)
        } else {
            element = nil
        }

        if let element {
            if let selected = stringAttribute(kAXSelectedTextAttribute, element: element), !selected.isEmpty {
                return TextSnapshot(element: element, text: selected, isSelection: true, usesClipboard: false)
            }
            if let value = stringAttribute(kAXValueAttribute, element: element), !value.isEmpty {
                return TextSnapshot(element: element, text: value, isSelection: false, usesClipboard: false)
            }
        }
        return try await captureUsingClipboard(element: element)
    }

    static func replace(_ snapshot: TextSnapshot, with corrected: String) async throws {
        // Web contenteditable and Electron fields can report a successful AX write
        // while silently ignoring it. Pasting works consistently across those apps.
        try await pasteUsingClipboard(corrected, selectAll: !snapshot.isSelection)
    }

    private static func stringAttribute(_ attribute: String, element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        if let string = value as? String { return string }
        if let attributed = value as? NSAttributedString { return attributed.string }
        return nil
    }

    private static func captureUsingClipboard(element: AXUIElement?) async throws -> TextSnapshot {
        let pasteboard = NSPasteboard.general
        let backup = PasteboardBackup(pasteboard)
        pasteboard.clearContents()
        postCommandKey(keyCode: 8) // C
        try? await Task.sleep(nanoseconds: 140_000_000)

        if let selected = pasteboard.string(forType: .string), !selected.isEmpty {
            backup.restore(to: pasteboard)
            return TextSnapshot(element: element, text: selected, isSelection: true, usesClipboard: true)
        }

        pasteboard.clearContents()
        postCommandKey(keyCode: 0) // A
        try? await Task.sleep(nanoseconds: 50_000_000)
        postCommandKey(keyCode: 8) // C
        try? await Task.sleep(nanoseconds: 140_000_000)
        let wholeText = pasteboard.string(forType: .string)
        backup.restore(to: pasteboard)
        guard let wholeText, !wholeText.isEmpty else { throw TextBridgeError.noTextField }
        return TextSnapshot(element: element, text: wholeText, isSelection: false, usesClipboard: true)
    }

    private static func pasteUsingClipboard(_ text: String, selectAll: Bool) async throws {
        let pasteboard = NSPasteboard.general
        let backup = PasteboardBackup(pasteboard)
        if selectAll {
            postCommandKey(keyCode: 0) // A
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else { throw TextBridgeError.replacementFailed }
        postCommandKey(keyCode: 9) // V
        try? await Task.sleep(nanoseconds: 160_000_000)
        backup.restore(to: pasteboard)
    }

    private static func postCommandKey(keyCode: CGKeyCode) {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}

private struct PasteboardBackup {
    let items: [[NSPasteboard.PasteboardType: Data]]

    init(_ pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restored = items.map { values -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in values { item.setData(data, forType: type) }
            return item
        }
        if !restored.isEmpty { pasteboard.writeObjects(restored) }
    }
}
