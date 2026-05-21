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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configurePopover()
        installStatusItem()
        wireStatusUpdates()
        store.requestPermissions()

        hotKey.register { [weak self] in
            self?.store.toggleRecording()
        }

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

    private func wireStatusUpdates() {
        store.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                guard let button = self?.statusItem?.button else { return }
                button.image = NSImage(
                    systemSymbolName: isRecording ? "waveform.circle.fill" : "waveform.circle",
                    accessibilityDescription: isRecording ? "Whisp recording" : "Whisp"
                )
                button.contentTintColor = isRecording ? .systemRed : nil
            }
            .store(in: &cancellables)
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

