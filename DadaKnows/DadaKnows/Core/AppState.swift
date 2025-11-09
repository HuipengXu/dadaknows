//
//  AppState.swift
//  DadaKnows
//
//  全局应用状态管理
//

import Foundation
import SwiftUI

class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var hasCompletedOnboarding = false
    @Published var currentLanguage = "en"
    @Published var subscriptionStatus = "free"
    
    static let shared = AppState()
    
    private init() {
        // 首先验证配置
        guard Config.validateConfiguration() else {
            print("❌ 应用配置验证失败")
            return
        }
        
        checkAuthenticationStatus()
    }
    
    func checkAuthenticationStatus() {
        Task {
            do {
                // 正确检查Supabase中的当前用户会话
                let session = try await SupabaseClient.shared.supabase.auth.session

                await MainActor.run {
                    self.isLoading = false

                    // 检查session是否有效
                    if !session.accessToken.isEmpty && session.user.email != nil {
                        // 用户已登录且有有效会话
                        self.isAuthenticated = true
                        AuthManager.shared.currentUser = session.user
                        AuthManager.shared.isAuthenticated = true

                        if Config.isDebug {
                            print("✅ 用户已登录: \(session.user.email ?? "未知邮箱")")
                        }
                    } else {
                        // 用户未登录或会话无效
                        self.isAuthenticated = false
                        AuthManager.shared.currentUser = nil
                        AuthManager.shared.isAuthenticated = false

                        if Config.isDebug {
                            print("ℹ️ 用户未登录或会话已过期")
                        }
                    }
                }

            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.isAuthenticated = false
                    AuthManager.shared.currentUser = nil
                    AuthManager.shared.isAuthenticated = false

                    if Config.isDebug {
                        print("⚠️ 检查认证状态失败: \(error)")
                    }
                }
            }
        }
    }
    
    func signIn() {
        isAuthenticated = true
    }
    
    func signOut() {
        isAuthenticated = false
        // Clear user data
        subscriptionStatus = "free"
    }
    
    func updateSubscriptionStatus(_ status: String) {
        subscriptionStatus = status
    }
}
