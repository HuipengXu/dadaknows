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
    static let supabaseServiceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ3dnlyY2VrYm5nY3BpdWRsanBqIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjczNDg4NiwiZXhwIjoyMDcyMzEwODg2fQ.j1bediOZ0EmPAfo0FcMpbdp15ww1zB1XnhE1ialQrPs"
    
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
    /// 测试环境使用5次，生产环境使用3000次
    static let monthlyProQuestionLimit: Int = {
        #if DEBUG
        return 5  // 测试环境：5次
        #else
        return 3000  // 生产环境：3000次
        #endif
    }()
    
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
