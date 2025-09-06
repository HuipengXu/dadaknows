//
//  Colors.swift
//  DadaKnows
//
//  应用颜色系统 - 根据设计文档定义
//

import SwiftUI

extension Color {
    // MARK: - Primary Colors
    /// 奶油黄 (#FFF8E1) - 主要背景色
    static let creamYellow = Color(hex: "#FFF8E1")
    
    /// 活力橙 (#FFB347) - 主交互色，按钮/高亮
    static let vibrantOrange = Color(hex: "#FFB347")
    
    // MARK: - Secondary Colors
    /// 嫩黄色 (#FFEB3B) - 答答主体颜色
    static let tenderYellow = Color(hex: "#FFEB3B")
    
    /// 天空蓝 (#B3E5FC) - 年龄选择器头像、插画点缀
    static let skyBlue = Color(hex: "#B3E5FC")
    
    /// 珊瑚粉 (#FFAB91) - 年龄选择器头像、插画点缀
    static let coralPink = Color(hex: "#FFAB91")
    
    // MARK: - Premium Colors
    /// 浅金色渐变起始色 (#FFD700)
    static let lightGoldStart = Color(hex: "#FFD700")
    
    /// 浅金色渐变结束色 (#FFEB99)
    static let lightGoldEnd = Color(hex: "#FFEB99")
    
    /// 深蓝色渐变起始色 (#1976D2)
    static let deepBlueStart = Color(hex: "#1976D2")
    
    /// 深蓝色渐变结束色 (#2196F3)
    static let deepBlueEnd = Color(hex: "#2196F3")
    
    // MARK: - Text Colors
    /// 深灰色 (#333333) - 主要文本/图标色
    static let darkGray = Color(hex: "#333333")
    
    /// 浅灰色 (#999999) - 次要文本/提示色
    static let lightGray = Color(hex: "#999999")
    
    // MARK: - Background Colors
    /// 主背景色
    static let backgroundPrimary = Color.creamYellow
    
    /// 次要背景色
    static let backgroundSecondary = Color.white.opacity(0.9)
    
    // MARK: - Semantic Colors
    /// 主要文本色
    static let primaryText = Color.darkGray
    
    /// 次要文本色
    static let secondaryText = Color.lightGray
    
    // MARK: - Gradient Definitions
    static let proFreeGradient = LinearGradient(
        gradient: Gradient(colors: [lightGoldStart, lightGoldEnd]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let proActiveGradient = LinearGradient(
        gradient: Gradient(colors: [deepBlueStart, deepBlueEnd]),
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
