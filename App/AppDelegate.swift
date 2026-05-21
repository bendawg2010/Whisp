import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = DictationStore()
    let updater = UpdaterController()

    private let popover = NSPopover()
    private let hotKey = HotKeyController()
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    private var hudWindow: NSPanel?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configurePopover()
        installStatusItem()
        wireStatusUpdates()
        store.requestPermissions()

        registerHotkey()

        store.hotkeyChanged
            .sink { [weak self] in
                self?.registerHotkey()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)
            .sink { [weak self] notification in
                guard let window = notification.object as? NSWindow else { return }
                DispatchQueue.main.async {
                    // Check if there are any other visible windows (ignoring panels/popovers)
                    let normalWindows = NSApp.windows.filter { 
                        $0.isVisible && !$0.className.contains("NSPanel") && !$0.className.contains("NSPopover") 
                    }
                    if normalWindows.isEmpty {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
            }
            .store(in: &cancellables)

        updater.clearSkippedVersionsOnLaunch()
        _ = updater.controller
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.updater.runIndependentVersionCheck()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKey.unregister()
        store.cancelRecording()
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 430, height: 620)
        popover.contentViewController = NSHostingController(
            rootView: ContentView(store: store, updater: updater)
        )
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Whisp")
            button.imagePosition = .imageLeading
            button.title = " Whisp"
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func registerHotkey() {
        let mods = store.useCustomShortcut ? store.customModifiers : store.hotkeyModifiers.carbonModifiers
        let code = store.useCustomShortcut ? store.customKeyCode : store.hotkeyTriggerKey.keyCode
        hotKey.register(modifiers: mods, keyCode: code) { [weak self] isPressed in
            guard let self = self else { return }
            if isPressed {
                self.store.isHotkeyCurrentlyPressed = true
                if self.store.hotkeyMode == .hold {
                    self.store.startRecording()
                } else {
                    self.store.toggleRecording()
                }
            } else {
                self.store.hotkeyReleased()
                if self.store.hotkeyMode == .hold {
                    self.store.stopRecording()
                }
            }
        }
    }

    private func wireStatusUpdates() {
        store.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                guard let self = self else { return }
                
                if let button = self.statusItem?.button {
                    button.image = NSImage(
                        systemSymbolName: isRecording ? "waveform.circle.fill" : "waveform.circle",
                        accessibilityDescription: isRecording ? "Whisp recording" : "Whisp"
                    )
                    button.contentTintColor = isRecording ? .systemRed : nil
                }

                if isRecording {
                    self.showHUD()
                } else {
                    self.hideHUD()
                }
            }
            .store(in: &cancellables)
    }

    private func showHUD() {
        guard store.showFloatingHUD else { return }
        
        if hudWindow == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 56),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .statusBar
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            
            let hostingView = NSHostingView(rootView: FloatingHUDView(store: store))
            panel.contentView = hostingView
            
            self.hudWindow = panel
        }
        
        positionHUD()
        hudWindow?.orderFrontRegardless()
    }

    private func hideHUD() {
        hudWindow?.orderOut(nil)
    }

    private func positionHUD() {
        guard let panel = hudWindow, let screen = NSScreen.main else { return }
        
        let screenRect = screen.visibleFrame
        let panelSize = panel.frame.size
        
        let x = screenRect.origin.x + (screenRect.size.width - panelSize.width) / 2
        let y = screenRect.origin.y + 42
        
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button else { return }

        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showMenu(from: button)
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: store.isRecording ? "Stop Dictation" : "Start Dictation",
            action: #selector(toggleRecording),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Force Update Now", action: #selector(forceUpdateNow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit Whisp", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }

        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func toggleRecording() {
        store.toggleRecording()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Whisp Settings"
            window.contentViewController = NSHostingController(
                rootView: SettingsView(store: store, updater: updater)
            )
            window.center()
            window.setFrameAutosaveName("WhispSettingsWindow")
            window.isReleasedWhenClosed = false
            self.settingsWindow = window
        }

        NSApp.setActivationPolicy(.regular)
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func checkForUpdates() {
        updater.checkForUpdates(nil)
    }

    @objc private func forceUpdateNow() {
        updater.forceUpdateNow(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

