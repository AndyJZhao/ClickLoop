import Foundation

/// 方案管理器 - 负责持久化存储
class SchemeManager {
    private var schemes: [ClickScheme] = []
    private let fileURL: URL

    init(directoryURL: URL? = nil) {
        // 确定存储路径: ~/Library/Application Support/ClickLoop/schemes.json
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let clickLoopDir = directoryURL ?? appSupportURL.appendingPathComponent("ClickLoop")

        // 创建目录（如果不存在）
        try? FileManager.default.createDirectory(at: clickLoopDir, withIntermediateDirectories: true)

        fileURL = clickLoopDir.appendingPathComponent("schemes.json")

        // 加载现有方案
        loadSchemes()
    }

    // MARK: - 获取方案

    func getAllSchemes() -> [ClickScheme] {
        return schemes
    }

    // MARK: - 添加方案

    enum AddSchemeError: Error, LocalizedError {
        case duplicateName

        var errorDescription: String? {
            switch self {
            case .duplicateName:
                return "方案名称已存在"
            }
        }
    }

    func addScheme(_ scheme: ClickScheme) -> Result<Void, AddSchemeError> {
        // 检查名称是否重复
        if schemes.contains(where: { $0.name == scheme.name }) {
            return .failure(.duplicateName)
        }

        schemes.append(scheme)
        saveSchemes()
        return .success(())
    }

    // MARK: - 更新方案

    func updateScheme(at index: Int, with scheme: ClickScheme) -> Result<Void, Error> {
        guard index >= 0 && index < schemes.count else {
            return .failure(NSError(domain: "SchemeManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "索引越界"]))
        }

        schemes[index] = scheme
        saveSchemes()
        return .success(())
    }

    // MARK: - 删除方案

    func deleteScheme(at index: Int) -> Bool {
        guard index >= 0 && index < schemes.count else {
            return false
        }

        schemes.remove(at: index)
        saveSchemes()
        return true
    }

    // MARK: - 持久化

    private func loadSchemes() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("📁 方案文件不存在，加载默认预设")
            loadDefaultSchemes()
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let storedSchemes = try JSONDecoder().decode([StorableScheme].self, from: data)
            schemes = storedSchemes.compactMap { $0.toScheme() }
            print("✅ 已加载 \(schemes.count) 个方案")
        } catch {
            print("❌ 加载方案失败: \(error.localizedDescription)")
            loadDefaultSchemes()
        }
    }

    private func saveSchemes() {
        let storableSchemes = schemes.map { StorableScheme(from: $0) }

        do {
            let data = try JSONEncoder().encode(storableSchemes)
            try data.write(to: fileURL)
            print("💾 已保存 \(schemes.count) 个方案")
        } catch {
            print("❌ 保存方案失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 默认预设

    private func loadDefaultSchemes() {
        // 默认方案1: 左键 10次 1秒 快捷键⌥1
        let defaultScheme1 = ClickScheme(
            name: "预设1",
            button: .left,
            clickCount: 10,
            totalDuration: 1.0,
            hotkey: Hotkey(
                keyCode: 18,  // 数字键1
                commandKey: false,
                optionKey: true,
                controlKey: false,
                shiftKey: false
            ),
            isEnabled: false
        )

        // 默认方案2: 右键 10次 1秒 快捷键⌥2
        let defaultScheme2 = ClickScheme(
            name: "预设2",
            button: .right,
            clickCount: 10,
            totalDuration: 1.0,
            hotkey: Hotkey(
                keyCode: 19,  // 数字键2
                commandKey: false,
                optionKey: true,
                controlKey: false,
                shiftKey: false
            ),
            isEnabled: false
        )

        schemes = [defaultScheme1, defaultScheme2]
        saveSchemes()
    }

    func hasScheme(named name: String) -> Bool {
        return schemes.contains(where: { $0.name == name })
    }
}

// MARK: - 可存储方案（用于 JSON 序列化）

private struct StorableScheme: Codable {
    let id: String
    let name: String
    let buttonType: String
    let clickCount: Int
    let totalDuration: Double
    let keyCode: UInt16
    let commandKey: Bool
    let optionKey: Bool
    let controlKey: Bool
    let shiftKey: Bool
    let isEnabled: Bool
    let isUnlimited: Bool?

    init(from scheme: ClickScheme) {
        self.id = scheme.id.uuidString
        self.name = scheme.name
        self.buttonType = scheme.button == .left ? "left" : "right"
        self.clickCount = scheme.clickCount
        self.totalDuration = scheme.totalDuration
        self.keyCode = scheme.hotkey.keyCode
        self.commandKey = scheme.hotkey.modifierFlags.contains(.maskCommand)
        self.optionKey = scheme.hotkey.modifierFlags.contains(.maskAlternate)
        self.controlKey = scheme.hotkey.modifierFlags.contains(.maskControl)
        self.shiftKey = scheme.hotkey.modifierFlags.contains(.maskShift)
        self.isEnabled = scheme.isEnabled
        self.isUnlimited = scheme.isUnlimited
    }

    func toScheme() -> ClickScheme? {
        let button: MouseButton = buttonType == "left" ? .left : .right
        let hotkey = Hotkey(
            keyCode: keyCode,
            commandKey: commandKey,
            optionKey: optionKey,
            controlKey: controlKey,
            shiftKey: shiftKey
        )

        let scheme = ClickScheme(
            name: name,
            button: button,
            clickCount: clickCount,
            totalDuration: totalDuration,
            hotkey: hotkey,
            isEnabled: isEnabled,
            isUnlimited: isUnlimited ?? false,
            id: UUID(uuidString: id) ?? UUID()
        )

        return scheme
    }
}
