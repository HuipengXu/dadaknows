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
    /// 使用异步Task执行，避免阻塞主线程
    static func initialize() {
        // 使用异步Task执行管理器初始化，不阻塞App启动
        Task(priority: .userInitiated) {
            if Config.isDebug {
                print("🚀 AppInitializer: 开始异步预热单例管理器...")
                let startTime = Date()
                
                // 触发单例初始化
                _ = AIManager.shared
                _ = LocalAIManager.shared
                _ = SubscriptionManager.shared
                _ = OfflineManager.shared
                _ = AnalyticsManager.shared
                _ = SpeechRecognitionManager.shared
                
                // 预初始化Core Data以避免首次访问时的延迟
                _ = DataManager.shared.persistentContainer
                
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
                _ = DataManager.shared.persistentContainer
            }
        }
    }
}
