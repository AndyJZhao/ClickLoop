import Foundation
import Combine
import AppKit

class ClickerViewModel: ObservableObject {
    @Published var schemes: [ClickScheme] = []
    @Published var isRunning: Bool = false
    @Published var isClicking: Bool = false
    @Published var needsAccessibilityPermission = false
    @Published var monitoringFailed = false
    private var monitoringPaused = false
    private var permissionRetryTimer: Timer?

    private let schemeManager = SchemeManager()
    private let hotkeyMonitor = HotkeyMonitor()
    private let mouseClicker = MouseClicker()

    init() {
        mouseClicker.onRunningChanged = { [weak self] running in self?.isClicking = running }
        hotkeyMonitor.onEscape = { [weak self] in self?.stopClicking() }
        hotkeyMonitor.isClicking = { [weak self] in self?.isClicking == true }
        loadSchemes()

        // 如果有已启用的方案，自动启动监听器
        let enabledSchemes = schemes.filter { $0.isEnabled }
        if !enabledSchemes.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startClicker()
            }
        }
    }

    deinit {
        permissionRetryTimer?.invalidate()
        // 停止监听
        if isRunning {
            hotkeyMonitor.stopMonitoring()
        }
    }

    // MARK: - Scheme Management

    func loadSchemes() {
        schemes = schemeManager.getAllSchemes()
    }

    func addScheme(_ scheme: ClickScheme) {
        let result = schemeManager.addScheme(scheme)

        switch result {
        case .success:
            loadSchemes()

            // 如果正在运行，注册新快捷键
            if isRunning {
                registerHotkey(for: scheme)
            }
        case .failure(let error):
            showAlert(title: "添加方案失败", message: error.localizedDescription)
        }
    }

    func updateScheme(_ oldScheme: ClickScheme, with newScheme: ClickScheme) {
        if let index = schemes.firstIndex(where: { $0.id == oldScheme.id }) {
            let result = schemeManager.updateScheme(at: index, with: newScheme)

            switch result {
            case .success:
                // ⚠️ 关键：立即更新内存中的方案数组，确保 UI 立即刷新
                schemes[index] = newScheme

                startClicker()
            case .failure(let error):
                showAlert(title: "更新方案失败", message: error.localizedDescription)
            }
        }
    }

    func deleteScheme(_ scheme: ClickScheme) {
        if let index = schemes.firstIndex(where: { $0.id == scheme.id }) {
            if schemeManager.deleteScheme(at: index) {
                loadSchemes()

                startClicker()
            }
        }
    }

    func toggleScheme(_ scheme: ClickScheme) {
        guard let index = schemes.firstIndex(where: { $0.id == scheme.id }) else { return }

        // ⚠️ 关键：直接切换状态（立即生效）
        schemes[index].isEnabled.toggle()

        let newState = schemes[index].isEnabled
        print("🔄 切换方案状态: \(scheme.name), 新状态: \(newState ? "启用" : "禁用")")

        _ = schemeManager.updateScheme(at: index, with: schemes[index])

        startClicker()
    }

    func enableAllSchemes() {
        for (index, scheme) in schemes.enumerated() {
            if !scheme.isEnabled {
                var updatedScheme = scheme
                updatedScheme.isEnabled = true
                _ = schemeManager.updateScheme(at: index, with: updatedScheme)
            }
        }
        loadSchemes()

        startClicker()
    }

    // MARK: - 快捷键录制支持

    func pauseHotkeyMonitoring() {
        monitoringPaused = true
        stopClicker()
    }

    func resumeHotkeyMonitoring() {
        guard monitoringPaused else { return }
        monitoringPaused = false
        startClicker()
    }

    func disableAllSchemes() {
        for (index, scheme) in schemes.enumerated() {
            if scheme.isEnabled {
                var updatedScheme = scheme
                updatedScheme.isEnabled = false
                _ = schemeManager.updateScheme(at: index, with: updatedScheme)
            }
        }
        loadSchemes()

        // 停止全局监听
        if isRunning {
            stopClicker()
        }
    }

    // MARK: - Clicker Control

    func startClicker() {
        stopClicker()
        guard !monitoringPaused, schemes.contains(where: { $0.isEnabled }) else { return }
        needsAccessibilityPermission = !AXIsProcessTrusted()
        guard !needsAccessibilityPermission else {
            // Granting permission in Settings must recover without toggling a preset or relaunching.
            permissionRetryTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                if AXIsProcessTrusted() { self?.startClicker() }
            }
            return
        }
        for scheme in schemes where scheme.isEnabled { registerHotkey(for: scheme) }
        isRunning = hotkeyMonitor.startMonitoring()
        monitoringFailed = !isRunning
        NSLog("ClickLoop hotkey monitor ready: %d", isRunning)
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        startClicker()
    }

    func stopClicking() {
        mouseClicker.stop()
    }

    func stopClicker() {
        stopClicking()
        permissionRetryTimer?.invalidate()
        permissionRetryTimer = nil
        hotkeyMonitor.stopMonitoring()
        isRunning = false
        needsAccessibilityPermission = false
        monitoringFailed = false
    }

    private func registerHotkey(for scheme: ClickScheme) {
        let schemeId = scheme.id  // 捕获ID而不是整个scheme
        hotkeyMonitor.registerHotkey(scheme.hotkey) { [weak self] in
            guard let self = self, self.isRunning, !self.monitoringPaused else { return }

            // 通过ID查找最新的scheme，确保使用最新的参数
            guard let currentScheme = self.schemes.first(where: { $0.id == schemeId }) else {
                return
            }

            guard currentScheme.isEnabled else { return }
            if self.mouseClicker.activeSchemeID == currentScheme.id {
                self.stopClicking()
                return
            }

            // 强引用 mouseClicker 以确保执行期间不被释放
            let clicker = self.mouseClicker
            clicker.executeScheme(currentScheme)

            NSLog("ClickLoop started: %.4g CPS, unlimited: %d", 1 / currentScheme.clickInterval, currentScheme.isUnlimited)
        }
    }

    // MARK: - Helper Methods

    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }
}
