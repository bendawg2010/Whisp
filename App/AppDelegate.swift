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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configurePopover()
        installStatusItem()
        wireStatusUpdates()
        store.requestPermissions()

        registerHotkey()

        store.hotkeyModifiersChanged
            .sink { [weak self] combo in
                self?.registerHotkey(modifiers: combo.carbonModifiers)
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

    private func registerHotkey(modifiers: UInt32? = nil) {
        let mods = modifiers ?? store.hotkeyModifiers.carbonModifiers
        hotKey.register(modifiers: mods) { [weak self] in
            self?.store.toggleRecording()
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
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
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

