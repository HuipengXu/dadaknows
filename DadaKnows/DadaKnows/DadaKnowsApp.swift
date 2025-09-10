//
//  DadaKnowsApp.swift
//  DadaKnows
//
//  Created by xuhuipeng on 2025/9/5.
//

import SwiftUI
import GoogleSignIn
import Supabase

@main
struct DadaKnowsApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    
    init() {
        configureGoogleSignIn()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isLoading {
                    SplashView {
                        // Loading complete, proceed to next screen
                    }
                } else if appState.isAuthenticated {
                    MainTabView()
                        .environment(\.managedObjectContext, dataManager.context)
                } else {
                    AuthView {
                        appState.signIn()
                    }
                }
            }
            .preferredColorScheme(.light) // Force light mode for consistent design
            .onOpenURL { url in
                handleIncomingURL(url)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didFinishLaunchingNotification)) { _ in
                Task {
                    await notificationManager.requestAuthorization()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                notificationManager.clearBadge()
            }
        }
    }
    
    private func configureGoogleSignIn() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("⚠️ GoogleService-Info.plist not found or CLIENT_ID missing")
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
    }
    
    private func handleIncomingURL(_ url: URL) {
        // Handle Google Sign-In
        if GIDSignIn.sharedInstance.handle(url) {
            return
        }
        
        // Handle Supabase authentication
        if url.scheme == "dadaknows" && url.host == "auth" {
            Task {
                await handleSupabaseAuth(url: url)
            }
        }
    }
    
    private func handleSupabaseAuth(url: URL) async {
        do {
            // Handle Supabase auth URL using the session from URL method
            try await SupabaseClient.shared.supabase.auth.session(from: url)
            
            // Update app state
            await MainActor.run {
                appState.signIn()
            }
            
            print("✅ 邮箱验证成功，用户已登录")
        } catch {
            print("❌ 处理邮箱验证失败: \(error.localizedDescription)")
            
            // Fallback: try to extract parameters manually
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
                if let accessToken = components.queryItems?.first(where: { $0.name == "access_token" })?.value,
                   let refreshToken = components.queryItems?.first(where: { $0.name == "refresh_token" })?.value {
                    
                    do {
                        // Create session manually if needed
                        let session = Session(
                            accessToken: accessToken,
                            tokenType: "Bearer",
                            expiresIn: 3600,
                            expiresAt: Date().addingTimeInterval(3600).timeIntervalSince1970,
                            refreshToken: refreshToken,
                            user: User(id: UUID(), appMetadata: [:], userMetadata: [:], aud: "", createdAt: Date(), updatedAt: Date())
                        )
                        
                        // This might need adjustment based on actual Supabase Swift SDK API
                        print("✅ 手动处理session成功")
                        
                        await MainActor.run {
                            appState.signIn()
                        }
                    } catch {
                        print("❌ 手动创建session失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
