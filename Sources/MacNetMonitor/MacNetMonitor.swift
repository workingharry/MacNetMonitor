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
        window.isReleasedWhenClosed = false // Prevent window deallocation on red X close
        window.setFrameAutosaveName("MacNetMonitorMainWindow")
        window.contentView = NSHostingView(rootView: contentView)
        window.title = "Network Usage Monitor"
        window.makeKeyAndOrderFront(nil)
        self.window = window

        updateWindowVisibilityState()

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Robust Window Visibility Resolution
    private func updateWindowVisibilityState() {
        guard let win = window else {
            viewModel?.isWindowVisible = false
            return
        }

        let isKeyOrVisible = win.isVisible
        let isOccluded = !win.occlusionState.contains(.visible)
        let isMiniaturized = win.isMiniaturized

        let resolved = MonitoringCadencePolicy.resolveWindowVisibility(
            isKeyOrVisible: isKeyOrVisible,
            isOccluded: isOccluded,
            isMiniaturized: isMiniaturized
        )
        viewModel?.isWindowVisible = resolved
    }

    func windowDidMiniaturize(_ notification: Notification) {
        updateWindowVisibilityState()
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        updateWindowVisibilityState()
    }

    func windowWillClose(_ notification: Notification) {
        viewModel?.isWindowVisible = false
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        viewModel?.isWindowVisible = false
        return false // Intercept red button: hide window instead of destroying
    }

    func windowDidChangeOcclusionState(_ notification: Notification) {
        updateWindowVisibilityState()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        updateWindowVisibilityState()
    }

    func windowDidResignKey(_ notification: Notification) {
        updateWindowVisibilityState()
    }

    private func setupMenuBarItem(viewModel: NetworkMonitorViewModel) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }

        button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Network Monitor")
        button.action = #selector(menuBarButtonClicked)
        button.target = self

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
        guard let window = self.window else { return }
        if window.isVisible {
            window.orderOut(nil)
            viewModel?.isWindowVisible = false
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            updateWindowVisibilityState()
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
