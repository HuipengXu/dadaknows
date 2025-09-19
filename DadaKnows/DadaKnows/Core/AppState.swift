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
        // Simulate auth check
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false
            // For now, simulate unauthenticated state to show auth flow
            self.isAuthenticated = false
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
