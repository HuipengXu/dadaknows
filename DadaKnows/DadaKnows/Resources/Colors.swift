//
//  Colors.swift
//  DadaKnows
//
//  iOS原生颜色系统 - 符合Apple设计规范
//

import SwiftUI

extension Color {
    // MARK: - iOS Native System Colors
    
    // MARK: - Primary Colors
    /// 主色调 - iOS系统蓝色
    static let appPrimary = Color.blue
    
    /// 次要色调 - iOS系统绿色
    static let appSecondary = Color.green
    
    /// 强调色 - iOS系统橙色
    static let appAccent = Color.orange
    
    // MARK: - Background Colors
    /// 主背景色 - 系统背景
    static let backgroundPrimary = Color(UIColor.systemBackground)
    
    /// 次要背景色 - 系统分组背景
    static let backgroundSecondary = Color(UIColor.systemGroupedBackground)
    
    /// 第三级背景色 - 系统分组背景（次要）
    static let backgroundTertiary = Color(UIColor.secondarySystemGroupedBackground)
    
    /// 卡片背景色
    static let cardBackground = Color(UIColor.tertiarySystemGroupedBackground)
    
    // MARK: - Text Colors
    /// 主要文本色 - 系统标签色
    static let textPrimary = Color(UIColor.label)
    
    /// 次要文本色 - 系统次要标签色
    static let textSecondary = Color(UIColor.secondaryLabel)
    
    /// 第三级文本色 - 系统第三级标签色
    static let textTertiary = Color(UIColor.tertiaryLabel)
    
    /// 占位符文本色 - 系统占位符文本色
    static let textPlaceholder = Color(UIColor.placeholderText)
    
    // MARK: - Separator Colors
    /// 分割线颜色 - 系统分割线
    static let separator = Color(UIColor.separator)
    
    /// 不透明分割线颜色
    static let separatorOpaque = Color(UIColor.opaqueSeparator)
    
    // MARK: - Fill Colors
    /// 填充色 - 系统填充色
    static let fillPrimary = Color(UIColor.systemFill)
    
    /// 次要填充色
    static let fillSecondary = Color(UIColor.secondarySystemFill)
    
    /// 第三级填充色
    static let fillTertiary = Color(UIColor.tertiarySystemFill)
    
    /// 第四级填充色
    static let fillQuaternary = Color(UIColor.quaternarySystemFill)
    
    // MARK: - Status Colors
    /// 成功色
    static let statusSuccess = Color.green
    
    /// 警告色
    static let statusWarning = Color.orange
    
    /// 错误色
    static let statusError = Color.red
    
    /// 信息色
    static let statusInfo = Color.blue
    
    // MARK: - Semantic Colors for App Features
    /// 用户消息气泡颜色
    static let userMessageBackground = Color.blue
    
    /// AI消息气泡颜色
    static let aiMessageBackground = Color(UIColor.systemGray5)
    
    /// Pro会员颜色
    static let proMemberColor = Color.blue
    
    // MARK: - Backward Compatibility (临时保留，逐步替换)
    @available(*, deprecated, message: "Use iOS native colors instead")
    static let creamYellow = Color(UIColor.systemBackground)
    
    @available(*, deprecated, message: "Use Color.appPrimary instead")
    static let vibrantOrange = Color.orange
    
    @available(*, deprecated, message: "Use iOS native colors instead")
    static let tenderYellow = Color.yellow
    
    @available(*, deprecated, message: "Use iOS native colors instead")
    static let skyBlue = Color.blue.opacity(0.3)
    
    @available(*, deprecated, message: "Use iOS native colors instead")
    static let coralPink = Color.pink.opacity(0.3)
    
    @available(*, deprecated, message: "Use Color.textPrimary instead")
    static let darkGray = Color(UIColor.label)
    
    @available(*, deprecated, message: "Use Color.textSecondary instead")
    static let lightGray = Color(UIColor.secondaryLabel)
    
    @available(*, deprecated, message: "Use Color.textPrimary instead")
    static let primaryText = Color(UIColor.label)
    
    @available(*, deprecated, message: "Use Color.textSecondary instead")
    static let secondaryText = Color(UIColor.secondaryLabel)
    
    // MARK: - Gradient Definitions (Updated for iOS native)
    static let proFreeGradient = LinearGradient(
        gradient: Gradient(colors: [Color.orange, Color.yellow]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let proActiveGradient = LinearGradient(
        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
