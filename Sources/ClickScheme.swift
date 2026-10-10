import Foundation
import CoreGraphics

/// 鼠标按键类型
enum MouseButton: String, Hashable, Codable {
    case left
    case right

    var downEventType: CGEventType {
        switch self {
        case .left: return .leftMouseDown
        case .right: return .rightMouseDown
        }
    }

    var upEventType: CGEventType {
        switch self {
        case .left: return .leftMouseUp
        case .right: return .rightMouseUp
        }
    }
}

/// 连点方案
struct ClickScheme: Hashable, Identifiable, Codable {
    let id: UUID
    var name: String
    var button: MouseButton
    var targetCPS: Double
    var totalDuration: TimeInterval // 总完成时间（秒）
    var hotkey: Hotkey
    var isEnabled: Bool  // 方案启用状态
    var isUnlimited: Bool = false

    var clickInterval: TimeInterval { 1 / targetCPS }

    // The first click is immediate; include each scheduled click before duration expires.
    var clickCount: Int {
        guard Self.isValidTiming(targetCPS: targetCPS, duration: totalDuration) else { return 0 }
        return Int(ceil(targetCPS * totalDuration))
    }

    static func isValidTiming(targetCPS: Double, duration: TimeInterval) -> Bool {
        let count = targetCPS * duration
        return targetCPS.isFinite && targetCPS > 0 && targetCPS <= 200 &&
            (1 / targetCPS).isFinite && duration.isFinite && duration > 0 &&
            count > 0 && count < Double(Int.max)
    }

    init(name: String, button: MouseButton, targetCPS: Double, totalDuration: TimeInterval, hotkey: Hotkey, isEnabled: Bool = false, isUnlimited: Bool = false, id: UUID = UUID()) {
        self.id = id
        self.name = name
        self.button = button
        self.targetCPS = targetCPS
        self.totalDuration = totalDuration
        self.hotkey = hotkey
        self.isEnabled = isEnabled
        self.isUnlimited = isUnlimited
    }
}

/// 快捷键定义
struct Hotkey: Hashable, Codable {
    static let unassignedKey = UInt16.max
    let keyCode: UInt16
    let modifierFlags: CGEventFlags

    init(keyCode: UInt16, commandKey: Bool = false, optionKey: Bool = false, controlKey: Bool = false, shiftKey: Bool = false) {
        self.keyCode = keyCode

        var flags = CGEventFlags()
        if commandKey { flags.insert(.maskCommand) }
        if optionKey { flags.insert(.maskAlternate) }
        if controlKey { flags.insert(.maskControl) }
        if shiftKey { flags.insert(.maskShift) }

        self.modifierFlags = flags
    }

    // Codable 支持
    enum CodingKeys: String, CodingKey {
        case keyCode
        case modifierFlagsRawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.keyCode = try container.decode(UInt16.self, forKey: .keyCode)
        let flagsRawValue = try container.decode(UInt64.self, forKey: .modifierFlagsRawValue)
        self.modifierFlags = CGEventFlags(rawValue: flagsRawValue)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(modifierFlags.rawValue, forKey: .modifierFlagsRawValue)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(modifierFlags.rawValue)
    }

    static func == (lhs: Hotkey, rhs: Hotkey) -> Bool {
        return lhs.keyCode == rhs.keyCode && lhs.modifierFlags == rhs.modifierFlags
    }
}

// 常用按键的 KeyCode 映射
extension Hotkey {
    // Letter keys
    static let keyA: UInt16 = 0
    static let keyS: UInt16 = 1
    static let keyD: UInt16 = 2
    static let keyF: UInt16 = 3
    static let keyR: UInt16 = 15
    static let keyL: UInt16 = 37
}
