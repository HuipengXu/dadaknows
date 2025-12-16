//
//  AppInitializer.swift
//  DadaKnows
//
//  应用初始化器 - 在应用启动时预热单例
//  避免在用户交互时才初始化，减少UI卡顿
//

import Foundation
import SwiftUI

@MainActor
class AppInitializer {
    /// 预热应用的核心单例管理器
    /// 在应用启动时调用，将初始化工作分散到启动期间，而不是集中在首次UI交互时
    static func initialize() {
        if Config.isDebug {
            print("🚀 AppInitializer: 开始预热单例管理器...")
            let startTime = Date()
            
            // 预热核心管理器（触发它们的init方法）
            _ = AIManager.shared
            _ = LocalAIManager.shared
            _ = SubscriptionManager.shared
            _ = OfflineManager.shared
            _ = AnalyticsManager.shared
            _ = SpeechRecognitionManager.shared
            
            let duration = Date().timeIntervalSince(startTime)
            print("✅ AppInitializer: 单例预热完成，耗时: \(String(format: "%.2f", duration * 1000))ms")
        } else {
            // 生产环境也需要预热，但不打印日志
            _ = AIManager.shared
            _ = LocalAIManager.shared
            _ = SubscriptionManager.shared
            _ = OfflineManager.shared
            _ = AnalyticsManager.shared
            _ = SpeechRecognitionManager.shared
        }
    }
}
