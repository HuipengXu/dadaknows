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
        }
        
        return true
    }
}
