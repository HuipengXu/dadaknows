//
//  DadaKnowsApp.swift
//  DadaKnows
//
//  Created by xuhuipeng on 2025/9/5.
//

import SwiftUI
import GoogleSignIn

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
                GIDSignIn.sharedInstance.handle(url)
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
}
