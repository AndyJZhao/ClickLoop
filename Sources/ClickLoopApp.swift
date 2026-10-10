import SwiftUI
import AppKit
import QuartzCore
import Combine

@main
struct ClickLoopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.viewModel)
                .frame(width: 310, height: 400)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        .defaultSize(width: 310, height: 422)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var clickingObservation: AnyCancellable?
    private var cpsObservation: AnyCancellable?
    private let cpsOverlay = CPSOverlayController()
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    // ⚠️ 关键：在 AppDelegate 中持有 ViewModel，确保窗口关闭后仍然运行
    // 使用 lazy var 确保只初始化一次
    static var shared: AppDelegate?
    lazy var viewModel: ClickerViewModel = {
        return ClickerViewModel()
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ⚠️ 关键：只创建菜单栏图标，不检查权限
        // 权限检查会在真正需要时（启用方案时）进行
        AppDelegate.shared = self
        // 强制初始化 viewModel
        _ = viewModel
        setupMenuBarIcon()
        clickingObservation = viewModel.$isClicking
            .removeDuplicates()
            .sink { [weak self] in self?.updateClickingIndicator($0) }
        cpsObservation = viewModel.$actualCPS
            .sink { [weak self] in self?.cpsOverlay.update($0) }
    }

    func setupMenuBarIcon() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "hand.point.up.left.fill", accessibilityDescription: "ClickLoop")
            button.action = #selector(togglePopover)
            button.target = self
            button.toolTip = "ClickLoop"
            if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                button.wantsLayer = true
                let pulse = CABasicAnimation(keyPath: "opacity")
                pulse.fromValue = 0.25
                pulse.toValue = 1
                pulse.duration = 0.35
                pulse.autoreverses = true
                pulse.repeatCount = 3
                button.layer?.add(pulse, forKey: "launchPulse")
            }
        }
    }

    private func updateClickingIndicator(_ isClicking: Bool) {
        if isClicking { cpsOverlay.show() } else { cpsOverlay.hide() }
        guard let statusItem = statusItem, let button = statusItem.button else { return }
        statusItem.length = isClicking ? NSStatusItem.variableLength : NSStatusItem.squareLength
        button.image = NSImage(systemSymbolName: isClicking ? "cursorarrow.click" : "hand.point.up.left.fill",
                               accessibilityDescription: isClicking ? "Clicking" : "ClickLoop")
        button.title = isClicking ? " Clicking" : ""
        button.contentTintColor = isClicking ? .systemGreen : nil
        button.toolTip = isClicking ? "ClickLoop — Clicking · \(L.moveToStop)" : "ClickLoop"
        button.setAccessibilityLabel(isClicking ? "ClickLoop — Clicking" : "ClickLoop")
    }

    @objc func togglePopover() {
        if let popover = popover, popover.isShown {
            popover.close()
        } else {
            showPopover()
        }
    }

    func showPopover() {
        guard let button = statusItem?.button else { return }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 200)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarView().environmentObject(viewModel))

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        self.popover = popover
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stopClicking()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // 关闭窗口不退出应用
    }
}

// 菜单栏弹出视图
struct MenuBarView: View {
    @EnvironmentObject private var viewModel: ClickerViewModel

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 32))
                .foregroundColor(.blue)

            Text("ClickLoop")
                .font(.headline)

            // 显示运行状态
            if viewModel.isClicking {
                Label(L.clicking, systemImage: "cursorarrow.click")
                    .foregroundColor(.green)
                Text(L.moveToStop)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if viewModel.isRunning {
                let enabledCount = viewModel.schemes.filter { $0.isEnabled }.count
                Text(L.runningStatus(count: enabledCount))
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Text(L.disabled)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if viewModel.isClicking {
                Button(L.stopClicking, action: viewModel.stopClicking)
                    .tint(.red)
                    .buttonStyle(.borderedProminent)
            }

            Divider()

            Button(L.showMainWindow) {
                NSApplication.shared.activate(ignoringOtherApps: true)
                NSApplication.shared.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
            }
            .buttonStyle(.borderedProminent)

            Button(L.quit) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
