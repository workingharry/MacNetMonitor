import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem?
    var window: NSWindow?
    private var viewModel: NetworkMonitorViewModel?
    private var lastRenderedTitle: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let vm = NetworkMonitorViewModel()
        self.viewModel = vm

        // Setup status bar item
        setupMenuBarItem(viewModel: vm)

        // Setup Main Window
        let contentView = ContentView(viewModel: vm)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 750),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.delegate = self
        window.setFrameAutosaveName("MacNetMonitorMainWindow")
        window.contentView = NSHostingView(rootView: contentView)
        window.title = "Network Usage Monitor"
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Window Visibility & Occlusion Tracking
    func windowDidMiniaturize(_ notification: Notification) {
        viewModel?.isWindowVisible = false
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        viewModel?.isWindowVisible = true
    }

    func windowWillClose(_ notification: Notification) {
        viewModel?.isWindowVisible = false
    }

    func windowDidChangeOcclusionState(_ notification: Notification) {
        if let win = window {
            let isVisible = win.isVisible && win.occlusionState.contains(.visible)
            viewModel?.isWindowVisible = isVisible
        }
    }

    private func setupMenuBarItem(viewModel: NetworkMonitorViewModel) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }

        button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Network Monitor")
        button.action = #selector(menuBarButtonClicked)
        button.target = self

        // Observe view model to update menu bar text dynamically with deduplication
        _ = viewModel.$currentDownloadSpeed
            .combineLatest(viewModel.$currentUploadSpeed)
            .receive(on: RunLoop.main)
            .sink { [weak self] down, up in
                guard let self = self, let button = self.statusItem?.button else { return }
                let downText = TrafficFormatter.formatSpeed(down)
                let upText = TrafficFormatter.formatSpeed(up)
                let newTitle = " ↓\(downText) ↑\(upText)"

                if MonitoringCadencePolicy.shouldUpdateTitle(current: self.lastRenderedTitle, new: newTitle) {
                    button.title = newTitle
                    self.lastRenderedTitle = newTitle
                }
            }
    }

    @objc private func menuBarButtonClicked() {
        if let window = self.window {
            if window.isVisible {
                window.orderOut(nil)
                viewModel?.isWindowVisible = false
            } else {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                viewModel?.isWindowVisible = true
            }
        }
    }
}

@main
enum MacNetMonitorMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
