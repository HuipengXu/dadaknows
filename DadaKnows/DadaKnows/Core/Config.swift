//
//  Config.swift
//  DadaKnows
//
//  环境配置管理
//

import Foundation

struct Config {
    // MARK: - Supabase Configuration
    static let supabaseURL = "https://fwvyrcekbngcpiudljpj.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ3dnlyY2VrYm5nY3BpdWRsanBqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY3MzQ4ODYsImV4cCI6MjA3MjMxMDg4Nn0.c62pXLg1sU8ZAz2bETNdtIKqBXnwGMzhj6M7cMIeUCg"
    
    // MARK: - AI Configuration
    static let geminiAPIKey = "AIzaSyD-YSyKmhc4d23ybooPBbJJaskhZshOV20"
    
    // MARK: - App Configuration
    static let feedbackEmail = "support@dada.llamafactory.cn"
    static let appStoreURL = "https://apps.apple.com/app/dadaknows" // 待更新为实际的App Store链接
    
    // MARK: - Foundation Models Configuration
    /// Foundation Models框架最低系统要求
    static let foundationModelsMinimumVersion = "26.0"
    
    /// 检查当前设备是否支持Foundation Models
    static var isFoundationModelsSupported: Bool {
        if #available(iOS 26.0, *) {
            return true
        } else {
            return false
        }
    }
    
    // MARK: - Usage Limits
    /// 普通用户每日免费使用次数限制（仅云端模型）
    /// 注意：本地模型不受此限制
    static let dailyFreeQuestionLimit = 2
    
    /// Pro用户每月远程模型使用次数限制
    /// 注意：本地模型不受此限制
    /// DEBUG/TestFlight/Sandbox环境使用5次，正式生产环境使用3000次
    static let monthlyProQuestionLimit: Int = {
        #if DEBUG
        return 5  // DEBUG环境：5次
        #else
        // 检测是否为 TestFlight/Sandbox 环境
        if isTestFlightOrSandbox {
            return 5  // TestFlight/Sandbox环境：5次
        }
        return 3000  // 正式生产环境：3000次
        #endif
    }()
    
    /// 检测是否为 TestFlight 或 Sandbox 环境
    static var isTestFlightOrSandbox: Bool {
        // 方法1：检查是否存在 receipt 文件（Sandbox 使用 sandboxReceipt）
        if let receiptURL = Bundle.main.appStoreReceiptURL {
            let receiptPath = receiptURL.path
            // Sandbox 或 TestFlight 的 receipt 路径包含 "sandboxReceipt"
            if receiptPath.contains("sandboxReceipt") {
                return true
            }
        }
        
        // 方法2：检查是否缺少 embedded.mobileprovision（App Store 版本没有此文件）
        // 如果存在此文件，说明是开发版本
        if Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil {
            return true
        }
        
        return false
    }
    
    // MARK: - Environment
    static let isDebug: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
    
    static let environment: Environment = .development
    
    enum Environment {
        case development
        case production
        
        var baseURL: String {
            switch self {
            case .development:
                return Config.supabaseURL
            case .production:
                return Config.supabaseURL
            }
        }
    }
    
    // MARK: - Validation
    static func validateConfiguration() -> Bool {
        guard !supabaseURL.isEmpty,
              !supabaseAnonKey.isEmpty,
              !geminiAPIKey.isEmpty else {
            if isDebug {
                print("❌ 配置验证失败：缺少必要的API密钥")
            }
            return false
        }
        
        if isDebug {
            print("✅ 配置验证成功")
            print("🔗 Supabase URL: \(supabaseURL)")
            print("🔑 API Keys已配置")
            print("📱 Foundation Models支持: \(isFoundationModelsSupported ? "是" : "否")")
            if !isFoundationModelsSupported {
                print("ℹ️ 当前系统版本不支持Foundation Models，将使用云端模型")
            }
        }
        
        return true
    }
}
