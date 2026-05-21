import AppKit

enum PasteService {
    /// The app the user was working in before Whisp started recording.
    private(set) static var previousApp: NSRunningApplication?

    /// Call when recording starts to snapshot the frontmost app.
    static func saveFrontmostApp() {
        let front = NSWorkspace.shared.frontmostApplication
        // Don't save ourselves as the target
        if front?.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = front
        }
    }

    /// Reactivate the user's app and paste the clipboard contents.
    static func pasteToFrontApp() {
        guard AXIsProcessTrusted() else {
            // Accessibility not granted — open the pane so the user can fix it
            openAccessibilitySettings()
            return
        }

        // Reactivate the previous app so the paste goes there
        if let app = previousApp {
            app.activate()
        }

        // Give the OS enough time to actually bring the window forward
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            sendPasteKeystroke()
        }
    }

    /// Raw Cmd+V keystroke via CGEvent (privateState so held modifier keys don't interfere).
    private static func sendPasteKeystroke() {
        let source = CGEventSource(stateID: .privateState)
        let keyV = CGKeyCode(0x09)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    /// Legacy convenience — still used in a few call-sites.
    static func paste() {
        pasteToFrontApp()
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

