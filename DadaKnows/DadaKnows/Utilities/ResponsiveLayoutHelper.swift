//
//  ResponsiveLayoutHelper.swift
//  DadaKnows
//
//  响应式布局助手 - 根据设备屏幕大小动态调整UI尺寸
//

import SwiftUI

/// 响应式布局助手，提供基于屏幕尺寸的自适应UI组件尺寸
struct ResponsiveLayoutHelper {

    // MARK: - Screen Size Detection

    /// 获取屏幕尺寸类型
    static func getScreenSizeCategory(_ geometry: GeometryProxy) -> ScreenSizeCategory {
        let width = geometry.size.width
        let height = geometry.size.height

        // iPad Landscape
        if width >= 1024 {
            return .ipadLandscape
        }
        // iPad Portrait
        else if width >= 768 {
            return .ipadPortrait
        }
        // Large iPhone (Plus/Pro Max)
        else if width >= 414 {
            return .iphoneLarge
        }
        // Regular iPhone
        else if width >= 375 {
            return .iphoneRegular
        }
        // Small iPhone (SE)
        else {
            return .iphoneSmall
        }
    }

    /// 获取水平尺寸类别
    static func getHorizontalSizeClass(_ geometry: GeometryProxy) -> HorizontalSizeClass {
        let width = geometry.size.width
        if width >= 768 {
            return .regular
        } else {
            return .compact
        }
    }

    // MARK: - Width Calculations

    /// 获取内容区域最大宽度
    static func getContentMaxWidth(_ geometry: GeometryProxy) -> CGFloat {
        let category = getScreenSizeCategory(geometry)
        let screenWidth = geometry.size.width

        switch category {
        case .ipadLandscape:
            return min(600, screenWidth * 0.5)
        case .ipadPortrait:
            return min(500, screenWidth * 0.7)
        case .iphoneLarge:
            return min(380, screenWidth * 0.9)
        case .iphoneRegular:
            return min(340, screenWidth * 0.9)
        case .iphoneSmall:
            return min(300, screenWidth * 0.9)
        }
    }

    /// 获取按钮最大宽度
    static func getButtonMaxWidth(_ geometry: GeometryProxy) -> CGFloat {
        return getContentMaxWidth(geometry)
    }

    /// 获取输入框最大宽度
    static func getInputFieldMaxWidth(_ geometry: GeometryProxy) -> CGFloat {
        return getContentMaxWidth(geometry)
    }

    // MARK: - Height Calculations

    /// 获取按钮高度
    static func getButtonHeight(_ geometry: GeometryProxy) -> CGFloat {
        let category = getScreenSizeCategory(geometry)
        switch category {
        case .ipadLandscape, .ipadPortrait:
            return 56  // iPad 需要更高的按钮
        case .iphoneLarge, .iphoneRegular, .iphoneSmall:
            return 50  // iPhone 保持当前尺寸
        }
    }

    /// 获取输入框高度
    static func getInputFieldHeight(_ geometry: GeometryProxy) -> CGFloat {
        let category = getScreenSizeCategory(geometry)
        switch category {
        case .ipadLandscape, .ipadPortrait:
            return 52  // iPad 输入框更高
        case .iphoneLarge, .iphoneRegular, .iphoneSmall:
            return 48  // iPhone 保持当前尺寸
        }
    }

    // MARK: - Spacing Calculations

    /// 获取垂直间距
    static func getVerticalSpacing(_ geometry: GeometryProxy, base: CGFloat = 16) -> CGFloat {
        let category = getScreenSizeCategory(geometry)
        let multiplier: CGFloat

        switch category {
        case .ipadLandscape:
            multiplier = 1.5
        case .ipadPortrait:
            multiplier = 1.3
        case .iphoneLarge:
            multiplier = 1.1
        case .iphoneRegular:
            multiplier = 1.0
        case .iphoneSmall:
            multiplier = 0.9
        }

        return base * multiplier
    }

    /// 获取内容区域边距
    static func getContentPadding(_ geometry: GeometryProxy) -> EdgeInsets {
        let category = getScreenSizeCategory(geometry)
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat

        switch category {
        case .ipadLandscape:
            horizontalPadding = 40
            verticalPadding = 32
        case .ipadPortrait:
            horizontalPadding = 32
            verticalPadding = 24
        case .iphoneLarge:
            horizontalPadding = 24
            verticalPadding = 20
        case .iphoneRegular:
            horizontalPadding = 20
            verticalPadding = 16
        case .iphoneSmall:
            horizontalPadding = 16
            verticalPadding = 16
        }

        return EdgeInsets(
            top: verticalPadding,
            leading: horizontalPadding,
            bottom: verticalPadding,
            trailing: horizontalPadding
        )
    }

    // MARK: - Font Size Calculations

    /// 获取标题字体大小
    static func getTitleFontSize(_ geometry: GeometryProxy) -> CGFloat {
        let category = getScreenSizeCategory(geometry)
        switch category {
        case .ipadLandscape, .ipadPortrait:
            return 34  // iPad 使用更大标题
        case .iphoneLarge, .iphoneRegular, .iphoneSmall:
            return 28  // iPhone 保持当前尺寸
        }
    }

    /// 获取副标题字体大小
    static func getSubtitleFontSize(_ geometry: GeometryProxy) -> CGFloat {
        let category = getScreenSizeCategory(geometry)
        switch category {
        case .ipadLandscape, .ipadPortrait:
            return 18  // iPad 副标题更大
        case .iphoneLarge, .iphoneRegular, .iphoneSmall:
            return 16  // iPhone 保持当前尺寸
        }
    }

    /// 获取按钮文字大小
    static func getButtonFontSize(_ geometry: GeometryProxy) -> CGFloat {
        let category = getScreenSizeCategory(geometry)
        switch category {
        case .ipadLandscape, .ipadPortrait:
            return 18  // iPad 按钮文字更大
        case .iphoneLarge, .iphoneRegular, .iphoneSmall:
            return 17  // iPhone 保持当前尺寸
        }
    }

    /// 获取输入框文字大小
    static func getInputFieldFontSize(_ geometry: GeometryProxy) -> CGFloat {
        let category = getScreenSizeCategory(geometry)
        switch category {
        case .ipadLandscape, .ipadPortrait:
            return 17  // iPad 输入框文字更大
        case .iphoneLarge, .iphoneRegular, .iphoneSmall:
            return 16  // iPhone 保持当前尺寸
        }
    }

    // MARK: - Logo Size Calculations

    /// 获取Logo尺寸
    static func getLogoSize(_ geometry: GeometryProxy) -> CGFloat {
        let category = getScreenSizeCategory(geometry)
        switch category {
        case .ipadLandscape:
            return 96
        case .ipadPortrait:
            return 80
        case .iphoneLarge, .iphoneRegular:
            return 64
        case .iphoneSmall:
            return 56
        }
    }

    // MARK: - Corner Radius

    /// 获取圆角半径
    static func getCornerRadius(_ geometry: GeometryProxy, base: CGFloat = 10) -> CGFloat {
        let category = getScreenSizeCategory(geometry)
        switch category {
        case .ipadLandscape, .ipadPortrait:
            return base * 1.2
        case .iphoneLarge, .iphoneRegular, .iphoneSmall:
            return base
        }
    }
}

// MARK: - Supporting Enums

/// 屏幕尺寸类别
enum ScreenSizeCategory {
    case iphoneSmall     // iPhone SE: < 375pt
    case iphoneRegular   // iPhone 12/13: 375-413pt
    case iphoneLarge     // iPhone Plus/Pro Max: 414-768pt
    case ipadPortrait    // iPad Portrait: 768-1023pt
    case ipadLandscape   // iPad Landscape: >= 1024pt
}

/// 水平尺寸类别
enum HorizontalSizeClass {
    case compact    // iPhone-sized width
    case regular    // iPad-sized width
}

// MARK: - SwiftUI Extensions

extension View {
    /// 应用响应式内容最大宽度
    func responsiveMaxWidth(_ geometry: GeometryProxy) -> some View {
        self.frame(maxWidth: ResponsiveLayoutHelper.getContentMaxWidth(geometry))
    }

    /// 应用响应式按钮尺寸
    func responsiveButtonSize(_ geometry: GeometryProxy) -> some View {
        self
            .frame(maxWidth: ResponsiveLayoutHelper.getButtonMaxWidth(geometry))
            .frame(height: ResponsiveLayoutHelper.getButtonHeight(geometry))
    }

    /// 应用响应式输入框尺寸
    func responsiveInputFieldSize(_ geometry: GeometryProxy) -> some View {
        self
            .frame(maxWidth: ResponsiveLayoutHelper.getInputFieldMaxWidth(geometry))
            .frame(height: ResponsiveLayoutHelper.getInputFieldHeight(geometry))
    }

    /// 应用响应式字体大小
    func responsiveFont(size: CGFloat, geometry: GeometryProxy, weight: Font.Weight = .regular) -> some View {
        let fontSize: CGFloat
        let category = ResponsiveLayoutHelper.getScreenSizeCategory(geometry)

        switch category {
        case .ipadLandscape, .ipadPortrait:
            fontSize = size * 1.2
        case .iphoneLarge:
            fontSize = size * 1.1
        case .iphoneRegular:
            fontSize = size
        case .iphoneSmall:
            fontSize = size * 0.9
        }

        return self.font(.system(size: fontSize, weight: weight))
    }
}